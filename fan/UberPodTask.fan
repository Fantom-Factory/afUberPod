using build::BuildPod
using build::Task

**
** pre>
** meta["afBuild.uberPods"] = "afFom afEfan afConcurrent/AtomicMap.fan"
** <pre
**
class UberPodTask : Task {
	private BuildPod	build
	private Str[]		allPodNames
	private SystemPods	sysPods
	private MyDir		uberDir
	private Str[]		uberPodNames
	private Str:Str[]	uberFilenames
	private Uri[]		uberSrcDirs
	private Depend[]	uberedPods
	private Depend[]    uberedTransDepends
	private MyEnv		myEnv
	private Str[]		allTransPodNames
	private Str[]		allTransPodFileNames
	
	new make(BuildPod build, MyEnv? myEnv := null) : super(script) {
		this.build			= build
		this.myEnv			= myEnv ?: MyEnv()
		this.allPodNames	= Str[,]
		this.sysPods		= SystemPods()
		this.uberDir		= MyDir(`build/afUberPod/`)
		this.uberPodNames	= build.meta["afBuild.uberPod"]?.split ?: Str#.emptyList
		this.uberFilenames	= [Str:Str[]][:] { it.def = Str#.emptyList }
		this.uberSrcDirs	= Uri[,]
		this.uberedPods		= Depend[,]
		this.allTransPodNames = [,]
		this.allTransPodFileNames = [,]
		this.uberedTransDepends = Depend[,]
		
		// split up names like afConcurrent/AtomicMap.fan
		uberPodNames = uberPodNames.map |podName| {
			
			if (podName.contains("/")) {
				split	 := podName.split('/')
				podName	  = split[0]
				fileName := split[1]
				if (!fileName.contains("."))
					fileName = fileName + ".fan"	// assume source files if not specified

				uberFilenames[podName] = uberFilenames[podName].rw.add(fileName)
			}
			
			// FIXME else add /*
			
			return podName
		}.unique
		
		// ensure afConcurrent/* will include everything
		uberFilenames.keys.each |pod| {
			if (uberFilenames[pod].any { it == "*" })
				uberFilenames.remove(pod)
		}
		
		
//		uberPodNames = init pods
//		uberFilenames = init files in pod
	}

	override Void run() {
		if (uberPodNames.isEmpty) return

		findTransDepends

		uberDir.delete
		uberDir.create

		explodeTransPods
		explodePods
		
		allPodNames.each { filterPodCode(it) }

		build.srcDirs = uberSrcDirs.unique
		build.depends = build.depends.map { Depend(it) }.exclude |Depend dep->Bool| {
			uberPodNames.any { dep.name == it }
		}.map { it.toStr }
		
		// it's useful to know exactly which versions were bundled
		build.meta["afBuild.uberPod.bundled"] = uberedPods.join("; ")
		build.log.info("UberPod - Ubered " + uberedPods.join(", "))
	}

	
	** Returns a list of *ALL* dependent pods (including transitive dependencies) EXCEPT pods that will be ubered.
	private Str[] flattenDepends() {
		toInspect := build.depends.map { Depend(it).name }.removeAll(uberPodNames)
		return collectDependencies(toInspect, Str[,]) |podName| { true }
	}
	
	private Void findTransDepends() {
		inspected := flattenDepends		// we don't inspect / uber pods that are hard dependencies
		toInspect := uberPodNames.dup.rw
		collected := collectDependencies(toInspect, Str[,]) |podName| { !sysPods.isSysPod(podName) && !sysPods.isSkyPod(podName) }
		
		uberPodNames.addAll(collected)
		allPodNames	= uberPodNames.dup.rw.add(build.podName)
	}

	private Void filterPodCode(Str podName) {
		usings1		:= allPodNames.map { "using ${it}"   }
		usings2		:= allPodNames.map { "using ${it}::" }
		uberSrcDir	:= uberDir + podName.toUri.plusSlash
		uberSrcDir.listFiles.each |fanFile| {
			if (fanFile.ext != "fan") return
			fanSrc := fanFile.readAllLines
			newSrc := fanSrc.exclude |fanLine| {
				usings1.any { fanLine == it }
			}

			// deal with "using XXX as YYY" statements
			mewAlt := false
			mewSrc := newSrc.map |fanLine| {
				if (usings2.any { fanLine.startsWith(it) }) {
					mewAlt = true
					return "using ${build.podName}" + fanLine[fanLine.index("::")..-1]
				}
				return fanLine
			}

			if (fanSrc.size != mewSrc.size || mewAlt)
				fanFile.write(mewSrc.join("\n"))
		}
	}

	private Void explodePods() {
		build.log.info("UberPod - exploding $build.podName ...")
		build.srcDirs?.each |srcDirUrl| {
			uberSrcDir := uberDir + build.podName.toUri.plusSlash
			if (MyDir(srcDirUrl).listFiles.size == 0)
			{
				uberDir = MyDir(`build/afUberPod/`)
				uberDir.createDir(build.podName)
			}
			else
			{
				MyDir(srcDirUrl).listFiles.each { 
					it.copyTo(uberSrcDir + it.name.toUri)
				}
				uberSrcDirs.add(uberSrcDir.uri.relTo(build.scriptDir.uri))
			}
		}
		
		uberPodNames.each |podName| {
			uberDir = MyDir(`build/afUberPod/`)
			uberPodDir	:= uberDir + podName.toUri.plusSlash
			
			myEnv.findPodFile(podName).open {

				includeFiles := uberFilenames[podName]
				if (includeFiles.isEmpty)
				{
					it.eachSrcFile |file, uri| {
						uberDstDir := uberPodDir + uri.relTo(`/src/`)
						
						file.copyTo(uberDstDir)
						uberSrcDirs.add(uberDstDir.uri.relTo(build.scriptDir.uri).parent)
					}
				}
				else
				{
					it.eachSrcFile |file, uri| {
						Bool fileFound := includeFiles.contains(file.name)
						if (fileFound)
						{
							uberDstDir := uberPodDir + uri.relTo(`/src/`)
						
							file.copyTo(uberDstDir)
						    uberSrcDirs.add(uberDstDir.uri.relTo(build.scriptDir.uri).parent)
						}
					}
				}
				

				uberedPods.add(it.asDepend)
			}
		}
	}

	private Void explodeTransPods() {
		uberPodNames.each() |podName| {
			myEnv.findPodFile(podName).open {
				if (it.podMeta["afBuild.uberPod"] != null) {
					it.podMeta["afBuild.uberPod"].split(' ').each() |transPod| {
						if (transPod.contains("/")) {
							split	 := transPod.split('/')
							podName	  = split[0]
							fileName := split[1]
							if (!fileName.contains("."))
								fileName = fileName + ".fan"	// assume source files if not specified
							uberFilenames[transPod] = uberFilenames[transPod].rw.add(fileName)
							allTransPodNames = allTransPodNames.add(podName)
							allTransPodFileNames = allTransPodFileNames.add(fileName)
						} else {
							allTransPodNames = allTransPodNames.add(transPod)
						}
					}
				}
			}
		}
		allTransPodNames.unique().each() |transPod| {
			allPodNames = allPodNames.add(transPod)
		}
		allTransPodNames.each() |podName| {
			addAll := false
			if (podName.contains("/")) {
				addAll = true
				podName = podName.split('/')[0]
			}
			uberDir = MyDir(`build/afUberPod/`)
			uberPodDir	:= uberDir + podName.toUri.plusSlash
			myEnv.findPodFile(podName).open {
				it.eachSrcFile |file, uri| {
					if (addAll) {
						uberDstDir := uberPodDir + uri.relTo(`/src/`)
						
						file.copyTo(uberDstDir)
						uberSrcDirs.add(uberDstDir.uri.relTo(build.scriptDir.uri).parent)
					} else {
						Bool fileFound := allTransPodFileNames.unique().contains(file.name)
						if (fileFound)
						{
							uberDstDir := uberPodDir + uri.relTo(`/src/`)
						
							file.copyTo(uberDstDir)
							uberSrcDirs.add(uberDstDir.uri.relTo(build.scriptDir.uri).parent)
						}
					}
					
				}
				uberedPods.add(it.asDepend)
			}
		}
	}
	
	** Walks the dependency tree, calling 'collect' on each depends.
	private Str[] collectDependencies(Str[] podNames, Str[] podsToIgnore, |Str podName->Bool| collect) {
		inspected := podsToIgnore.dup.rw
		toInspect := podNames.dup.rw
		collected := Str[,]
		
		while (toInspect.size > 0) {
			podName := toInspect.removeAt(0)
			if (inspected.contains(podName)) continue
			inspected.add(podName)

			myEnv.findPodFile(podName).open {				
				it.depends.each |dep| {
					toInspect.add(dep.name)

					if (collect(dep.name))
						collected.add(dep.name)
				}
			}
		}
		return collected
	}
}

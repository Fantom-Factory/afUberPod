using build::BuildPod
using build::Task

**
** pre>
** meta["afBuild.uberPods"] = "afFom afEfan afConcurrent/AtomicMap.fan"
** <pre
**
class UberPodTask : Task {
	private BuildPod	build
//	private Str[]		allPodNames
	private SystemPods	sysPods
//	private MyDir		uberDir
//	private Str[]		uberPodNames
//	private Str:Str[]	uberFilenames
//	private Uri[]		uberSrcDirs
//	private Depend[]	uberedPods
	private MyEnv		myEnv
//	private Str[]		allTransPodNames
//	private Str[]		allTransPodFileNames
	
	new make(BuildPod build, MyEnv? myEnv := null) : super(script) {
		this.build			= build
		this.myEnv			= myEnv ?: MyEnv()
//		this.allPodNames	= Str[,]
		this.sysPods		= SystemPods()
//		this.uberDir		= MyDir(`build/afUberPod/`)
//		this.uberPodNames	= build.meta["afBuild.uberPod"]?.split ?: Str#.emptyList
//		this.uberFilenames	= [Str:Str[]][:] { it.def = Str#.emptyList }
//		this.uberSrcDirs	= Uri[,]
//		this.uberedPods		= Depend[,]
//		this.allTransPodNames = [,]
//		this.allTransPodFileNames = [,]
		
//		// split up names like afConcurrent/AtomicMap.fan
//		uberPodNames = uberPodNames.map |podName| {
//			
//			if (podName.contains("/")) {
//				split	 := podName.split('/')
//				podName	  = split[0]
//				fileName := split[1]
//				if (!fileName.contains("."))
//					fileName = fileName + ".fan"	// assume source files if not specified
//
//				uberFilenames[podName] = uberFilenames[podName].rw.add(fileName)
//			}
//			
//			// FIXME else add /*
//			
//			return podName
//		}.unique
//		
//		// ensure afConcurrent/* will include everything
//		uberFilenames.keys.each |pod| {
//			if (uberFilenames[pod].any { it == "*" })
//				uberFilenames.remove(pod)
//		}
		
		
//		uberPodNames = init pods
//		uberFilenames = init files in pod
	}

	override Void run() {
		uberPodNames2 := (Str[]) (build.meta["afBuild.uberPod"]?.split ?: Str#.emptyList)
		if (uberPodNames2.isEmpty) return
		
		uberPodNames2 = uberPodNames2.map |podName| {
			podName.split('/').first
		}

		topLevelAllDepends		:= build.depends.map { Depend(it).name }
		topLevelUberDepends		:= uberPodNames2.dup
		topLevelNonUberDepends	:= topLevelAllDepends.removeAll(topLevelUberDepends)
		
		allNonUberDepends		:= flattenDepends(topLevelNonUberDepends,	true)
		allUberDepends			:= flattenDepends(topLevelUberDepends, 		false)
		
		// we need to remove non-uber trans deps from the uber deps (!) think of merging 2 trees
		allUberDepends			= allUberDepends.removeAll(allNonUberDepends)
		
		
//		findTransDepends

		uberDir := MyDir(`build/afUberPod/`)
		uberDir.delete
		uberDir.create

//		explodeTransPods
		
		uberFilenames := collectUberFilenames(allUberDepends)
		
		build.srcDirs = explodePods(uberDir, allUberDepends, uberFilenames)
		
		allUberDepends.each { filterPodCode(uberDir, allUberDepends, it) }

//		build.srcDirs = uberSrcDirs.unique	//FIXME
		
		buildDepends := (Depend[]) build.depends.map { Depend(it) }
		build.depends = buildDepends.exclude |dep| {
			topLevelUberDepends.any { dep.name == it }
		}.map { it.toStr }
		
		// it's useful to know exactly which versions were bundled
		bundled := allUberDepends.map { myEnv.findPodFile(it).open |pod| { pod.asDepend }.toStr }.join("; ")
		build.meta["afBuild.uberPod.bundled"] = bundled
		
//		build.meta["afBuild.uberPod.bundled"] = uberedPods.join("; ")	// FIXME find depends
		
		build.log.info("UberPod - Ubered " + allUberDepends.join(", "))
	}

	
	private Str[] flattenDepends(Str[] podNames, Bool includeSysPods) {
		collectDependencies(podNames, Str[,]) |podName| {
			includeSysPods ? true : !sysPods.isSysPod(podName) && !sysPods.isSkyPod(podName)
		}.addAll(podNames)
	}
	
//	** Returns a list of *ALL* dependent pods (including transitive dependencies) EXCEPT pods that will be ubered.
//	private Str[] flattenDepends(Str[] podNames) {
//		toInspect := podNames.removeAll(uberPodNames)
//		return collectDependencies(toInspect, Str[,]) |podName| { true }
//	}
//	
//	private Void findTransDepends() {
//		inspected := flattenDepends		// we don't inspect / uber pods that are hard dependencies
//		toInspect := uberPodNames.dup.rw
//		collected := collectDependencies(toInspect, Str[,]) |podName| { !sysPods.isSysPod(podName) && !sysPods.isSkyPod(podName) }
//		
//		uberPodNames.addAll(collected)
//		allPodNames	= uberPodNames.dup.rw.add(build.podName)
//	}

	Str:Str[] collectUberFilenames(Str[] uberPodNames) {
		uberFilenames	:= [Str:Str[]][:]
		
		// first collect filenames from the pod we're building
		addUberFilenames(uberFilenames, build.meta)

		// then from all the pods we're ubering up
		uberPodNames.each |podName| {
			myEnv.findPodFile(podName).open {
				addUberFilenames(uberFilenames, it.podMeta)
			}
		}
		
		// ensure afConcurrent/* will include everything
		uberFilenames.keys.each |pod| {
			if (uberFilenames[pod].any { it == "*" })
				uberFilenames.remove(pod)
		}
		
		return uberFilenames
	}

	private Obj? addUberFilenames(Str:Str[] uberFilenames, Str:Str podMeta) {
		uberMetas := (Str[]) (podMeta["afBuild.uberPod"]?.split ?: Str#.emptyList)
		uberMetas.each |uberMeta| {
			podName  := uberMeta
			fileName := "*"
			if (uberMeta.contains("/")) {
				split	 := podName.split('/')
				podName	 = split[0]
				fileName = split[1]
				if (!fileName.contains("."))
					fileName = fileName + ".fan"	// assume source files if not specified
			}
			fileList := uberFilenames.getOrAdd(podName) { Str[,] }
			fileList.add(fileName)
		}
		return null
	}
	
	private Uri[] explodePods(MyDir uberDir, Str[] podNames, Str:Str[] uberFilenames) {
		newSrcDirs := Uri[,]
		
		// first explode the pod we're building...
		build.log.info("UberPod - exploding $build.podName ...")
		build.srcDirs?.each |srcDirUrl| {
			uberSrcDir := uberDir + build.podName.toUri.plusSlash
			MyDir(srcDirUrl).listFiles.each { 
				it.copyTo(uberSrcDir + it.name.toUri)
			}
			newSrcDirs.add(uberSrcDir.uri.relTo(build.scriptDir.uri))
		}
		
		// then explode all the pods we're ubering up
//		uberDir = MyDir(`build/afUberPod/`)
		podNames.each |podName| {
			uberPodDir	:= uberDir + podName.toUri.plusSlash
			newSrcDirs.add(uberPodDir.uri)
			
			myEnv.findPodFile(podName).open |pod| {

				includeFiles := uberFilenames[podName]
				if (includeFiles == null) {
					pod.eachSrcFile |file, uri| {
						uberDstDir := uberPodDir + uri.relTo(`/src/`)
						
						file.copyTo(uberDstDir)
//						newSrcDirs.add(uberDstDir.uri.relTo(build.scriptDir.uri).parent)
					}
					
				} else {
					pod.eachSrcFile |file, uri| {
						// FIXME - roll up with above
						fileFound := includeFiles.contains(file.name)
						if (fileFound) {
							uberDstDir := uberPodDir + uri.relTo(`/src/`)
						
							file.copyTo(uberDstDir)
//						    newSrcDirs.add(uberDstDir.uri.relTo(build.scriptDir.uri).parent)
						}
					}
				}
				return null

//				uberedPods.add(it.asDepend)
			}
		}

		return newSrcDirs.unique
	}

	private Void filterPodCode(MyDir uberDir, Str[] allUberPodNames, Str podName) {
		usings1		:= allUberPodNames.map { "using ${it}"   }
		usings2		:= allUberPodNames.map { "using ${it}::" }
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

//	private Void explodeTransPods() {
//		uberPodNames.each() |podName| {
//			myEnv.findPodFile(podName).open {
//				if (it.podMeta["afBuild.uberPod"] != null) {
//					it.podMeta["afBuild.uberPod"].split(' ').each() |transPod| {
//						if (transPod.contains("/")) {
//							split	 := transPod.split('/')
//							podName	  = split[0]
//							fileName := split[1]
//							if (!fileName.contains("."))
//								fileName = fileName + ".fan"	// assume source files if not specified
//							uberFilenames[transPod] = uberFilenames[transPod].rw.add(fileName)
//							allTransPodNames = allTransPodNames.add(podName)
//							allTransPodFileNames = allTransPodFileNames.add(fileName)
//						} else {
//							allTransPodNames = allTransPodNames.add(transPod)
//						}
//					}
//				}
//			}
//		}
//		allTransPodNames.unique().each() |transPod| {
//			allPodNames = allPodNames.add(transPod)
//		}
//		allTransPodNames.each() |podName| {
//			addAll := false
//			if (podName.contains("/")) {
//				addAll = true
//				podName = podName.split('/')[0]
//			}
//			uberDir = MyDir(`build/afUberPod/`)
//			uberPodDir	:= uberDir + podName.toUri.plusSlash
//			myEnv.findPodFile(podName).open {
//				it.eachSrcFile |file, uri| {
//					if (addAll) {
//						uberDstDir := uberPodDir + uri.relTo(`/src/`)
//						
//						file.copyTo(uberDstDir)
//						uberSrcDirs.add(uberDstDir.uri.relTo(build.scriptDir.uri).parent)
//					} else {
//						Bool fileFound := allTransPodFileNames.unique().contains(file.name)
//						if (fileFound)
//						{
//							uberDstDir := uberPodDir + uri.relTo(`/src/`)
//						
//							file.copyTo(uberDstDir)
//							uberSrcDirs.add(uberDstDir.uri.relTo(build.scriptDir.uri).parent)
//						}
//					}
//					
//				}
//				uberedPods.add(it.asDepend)
//			}
//		}
//	}
	
	** Walks the dependency tree, calling 'collect' on each depends.
	private Str[] collectDependencies(Str[] podNames, Str[] podsToIgnore, |Str podName->Bool| collect) {
		inspected := podsToIgnore.dup.rw
		toInspect := podNames.dup.rw
		collected := Str[,]
		
		while (toInspect.size > 0) {
			podName := toInspect.removeAt(0)
			if (inspected.contains(podName)) continue
			inspected.add(podName)

			myEnv.findPodFile(podName).open |pod| {				
				pod.depends.each |dep| {
					toInspect.add(dep.name)

					if (collect(dep.name))
						collected.add(dep.name)
				}
				return null
			}
		}
		return collected
	}
}

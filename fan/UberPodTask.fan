using build::BuildPod
using build::Task

**
** pre>
** meta["afBuild.uberPods"] = "afFom afEfan afConcurrent/AtomicMap.fan"
** <pre
**
class UberPodTask : Task {
	private BuildPod	build
	private SystemPods	sysPods
	private MyEnv		myEnv
	
	new make(BuildPod build, MyEnv? myEnv := null) : super(script) {
		this.build			= build
		this.myEnv			= myEnv ?: MyEnv()
		this.sysPods		= SystemPods()
	}

	override Void run() {
		uberPodNames := (Str[]) (build.meta["afBuild.uberPod"]?.split?.map |podName| {
			podName.split('/').first
		} ?: Str#.emptyList)

		if (uberPodNames.isEmpty) return
		
		topLevelAllDepends		:= build.depends.map { Depend(it).name }
		topLevelUberDepends		:= uberPodNames
		topLevelNonUberDepends	:= topLevelAllDepends.removeAll(topLevelUberDepends)
		allNonUberDepends		:= flattenDepends(topLevelNonUberDepends,	true)
		allUberDepends			:= flattenDepends(topLevelUberDepends, 		false)
		
		// we need to remove non-uber trans deps from the uber deps (!) think of merging 2 trees
		allUberDepends			= allUberDepends.removeAll(allNonUberDepends)
		
		uberDir := MyDir(`build/afUberPod/`)
		uberDir.delete
		uberDir.create

		uberFilenames	:= collectUberFilenames(allUberDepends)
		srcDirs			:= explodePods(uberDir, uberFilenames)
		filterPodCode(uberDir, allUberDepends)

		buildDepends	:= (Depend[]) build.depends.map { Depend(it) }
		bundled			:= allUberDepends.map { myEnv.findPodFile(it).open |pod| { pod.asDepend }.toStr }.sort.join("; ")

		build.srcDirs	= srcDirs
		build.depends	= buildDepends.exclude |dep| { topLevelUberDepends.any { dep.name == it } }.map { it.toStr }
		build.meta["afBuild.uberPod.bundled"] = bundled
		
		build.log.info("UberPod - Ubered " + allUberDepends.join(", "))
	}

	
	private Str[] flattenDepends(Str[] podNames, Bool includeSysPods) {
		collectDependencies(podNames, Str[,]) |podName| {
			includeSysPods ? true : !sysPods.isSysPod(podName) && !sysPods.isSkyPod(podName)
		}.addAll(podNames)
	}

	Str:Str[] collectUberFilenames(Str[] uberPodNames) {
		uberFilenames	:= [Str:Str[]][:]
		
		// first collect filenames from the pod we're building
		addUberFilenames(uberFilenames, build.podName, build.meta)

		// then from all the pods we're ubering up
		uberPodNames.each |podName| {
			myEnv.findPodFile(podName).open {
				addUberFilenames(uberFilenames, podName, it.podMeta)
			}
		}
		
		// ensure afConcurrent/* will include everything
		uberFilenames.keys.each |pod| {
			if (uberFilenames[pod].any { it == "*" })
				uberFilenames[pod].clear
		}
		
		return uberFilenames
	}

	private Obj? addUberFilenames(Str:Str[] uberFilenames, Str pName, Str:Str podMeta) {
		uberMetas := (Str[]) (podMeta["afBuild.uberPod"]?.split ?: Str#.emptyList)
		if (uberMetas.isEmpty)
			uberFilenames.getOrAdd(pName) { Str["*"] }

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
	
	private Uri[] explodePods(MyDir uberDir, Str:Str[] uberFilenames) {
		newSrcDirs := Uri[,]
		
		// first explode the pod we're building...
		build.log.info("UberPod - exploding $build.podName ...")
		uberSrcDir := uberDir + build.podName.toUri.plusSlash
		newSrcDirs.add(uberSrcDir.uri)

		build.srcDirs?.each |srcDirUrl| {
			MyDir(srcDirUrl).listFiles.each { 
				it.copyInto(uberSrcDir + it.name.toUri)
			}
		}
		
		// then explode all the pods we're ubering up
		uberFilenames.each |includeFiles, podName| {
			build.log.info("UberPod - exploding $podName ...")
			uberSrcDir = uberDir + podName.toUri.plusSlash
			newSrcDirs.add(uberSrcDir.uri)

			uberDstDir := uberSrcDir	// + uri.relTo(`/src/`)
			myEnv.findPodFile(podName).open |pod| {
				pod.eachSrcFile |file, uri| {
					copyFile := includeFiles.isEmpty || includeFiles.contains(file.name)
					if (copyFile)
						file.copyInto(uberDstDir)
				}
				return null
			}
		}

		return newSrcDirs	//.unique
	}

	private Void filterPodCode(MyDir uberDir, Str[] allUberPodNames) {
		usings1		:= allUberPodNames.map { "using ${it}"   }
		usings2		:= allUberPodNames.map { "using ${it}::" }
		
		allUberPodNames.each |podName| {
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

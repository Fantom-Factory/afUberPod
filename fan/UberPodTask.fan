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
	private File		uberDir
	private Str[]		uberPodNames
	private Str:Str[]	uberFilenames
	private Uri[]		uberSrcDirs
	private Depend[]	uberDepends
	private Depend[]	uberedPods

	new make(BuildPod build) : super(script) {
		this.build			= build
		this.allPodNames	= Str[,]
		this.sysPods		= SystemPods()
		this.uberDir		= `build/afUberPod/`.toFile
		this.uberPodNames	= build.meta["afBuild.uberPod"]?.split ?: Str#.emptyList
		this.uberFilenames	= [Str:Str[]][:] { it.def = Str#.emptyList }
		this.uberSrcDirs	= Uri[,]
		this.uberDepends	= build.depends.map { Depend(it) }
		this.uberedPods		= Depend[,]

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
			return podName
		}.unique

		// ensure afConcurrent/* will include everything
		uberFilenames.keys.each |pod| {
			if (uberFilenames[pod].any { it == "*" })
				uberFilenames.remove(pod)
		}
	}

	override Void run() {
		if (uberPodNames.isEmpty) return

		findTransDepends

		uberDir.delete
		uberDir.create

		explodePods
		allPodNames.each { filterPodCode(it) }

		build.srcDirs = uberSrcDirs.unique
		build.depends = uberDepends.exclude |dep| {
			uberPodNames.any { dep.name == it }
		}.map { it.toStr }

		// it's useful to know exactly which versions were bundled
		build.meta["afBuild.uberPod.bundled"] = uberedPods.join("; ")
		build.log.info("UberPod - Ubered " + uberedPods.join(", "))
	}

	private Void findTransDepends() {
		transPodNamesTodo := uberPodNames.dup.rw
		transPodNamesDone := build.depends.map { Depend(it).name }.removeAll(transPodNamesTodo)

		while (transPodNamesTodo.size > 0) {
			transPodName := transPodNamesTodo.removeAt(0)
			if (transPodNamesDone.contains(transPodName)) continue

			podFile := Env.cur.findPodFile(transPodName)
			Zip.open(podFile) {
				meta := it.contents[`/meta.props`].readProps
				deps := (Depend[]) meta["pod.depends"].split(';').map { Depend(it) }

				deps.each |dep| {
					if (transPodNamesDone.contains(dep.name)) return

					if (sysPods.isSysPod(dep.name) || sysPods.isSkyPod(dep.name)) {
						// need to add this to build.deps
						udep := uberDepends.find { it.name == dep.name }
						if (udep != null) {
							// keep the newest dependency
							if (dep.version > udep.version)
								uberDepends.add(dep).remove(udep)
						} else {
							uberDepends.add(dep)
						}

					} else {
						if (!uberPodNames.contains(dep.name)) {
							uberPodNames.add(dep.name)
							transPodNamesTodo.add(dep.name)
						}
					}

				}
				transPodNamesDone.add(transPodName)

			}.close
		}
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
				fanFile.out.writeChars(mewSrc.join("\n")).flush.close
		}
	}

	private Void explodePods() {
		build.log.info("UberPod - exploding $build.podName ...")
		build.srcDirs?.each |srcDirUrl| {
			uberSrcDir := uberDir + build.podName.toUri.plusSlash
			srcDirUrl.toFile.listFiles.each { it.copyTo(uberSrcDir + it.name.toUri) }
			uberSrcDirs.add(uberSrcDir.uri.relTo(build.scriptDir.uri))
		}

		uberPodNames.each |podName| {
			uberPodDir	:= uberDir + podName.toUri.plusSlash
			podFile 	:= Env.cur.findPodFile(podName)
			podZip		:= Zip.open(podFile)

			try {
				podMeta	:= podZip.contents[`/meta.props`].readProps
				if (podMeta["pod.docSrc"] != "true")
					build.log.warn("$podName has NO src files!")
				else
					build.log.info("UberPod - exploding $podName ...")

				includeFiles := uberFilenames[podName]
				podZip.contents.each |file, uri| {
					if (includeFiles.size > 0 && !includeFiles.any { it == uri.name }) return
					if (uri.path.first != "src")				return
					if (uri.basename.endsWith("Test"))			return	// sometimes (in dev pods) test code sneaks in with the source!
					if (uri.basename.startsWith("Test"))		return	// sometimes (in dev pods) test code sneaks in with the source!
					uberDstDir := uberPodDir + uri.relTo(`/src/`)
					file.copyTo(uberDstDir)
					uberSrcDirs.add(uberDstDir.uri.relTo(build.scriptDir.uri).parent)
				}

				uberedPods.add(Depend(podName + " " + podMeta["pod.version"]))
			} finally
				podZip.close
		}
	}
}

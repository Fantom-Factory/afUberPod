using build::BuildPod
using build::Task

**
** pre>
** meta["afBuild.uberPods"] = "afFom afEfan"
** <pre
** 
class UberPodTask : Task {
	private BuildPod	build
	private File		uberDir
	private Str[]		allPodNames
	private Str[]		uberPodNames
	private Uri[]		uberSrcDirs
	private Depend[]	uberDepends
	private SystemPods	sysPods

	new make(BuildPod build) : super(script) {
		this.build			= build
		this.uberDir		= `build/afUberPod/`.toFile
		this.uberPodNames	= build.meta["afBuild.uberPods"]?.split ?: Str#.emptyList
		this.uberSrcDirs	= Uri[,]
		this.allPodNames	= Str[,]
		this.uberDepends	= build.depends.map { Depend(it) }
		this.sysPods		= SystemPods()
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
	}
	
	
	Str[] transPodNamesTodo		:= Str[,]
	Str[] transPodNamesDone		:= Str[,]
	private Void findTransDepends() {
		transPodNamesTodo = uberPodNames.dup.rw
		transPodNamesDone = build.depends.map { Depend(it).name }.removeAll(transPodNamesTodo)

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
						if (!uberPodNames.contains(dep.name))
							uberPodNames.add(dep.name)
					}

					transPodNamesDone.add(dep.name)
				}

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
				usings1.any { fanLine == it } ||
				usings2.any { fanLine.startsWith(it) }
			}

			// TODO make classes, enums, & mixins internal
//			newSrc.each |fanLine| {
//				if (fanLine.contains("class "))
//					echo(fanLine)
//			}
			
			// TODO deal with "using XXX as YYY" statements - should be fine to use proj pod name, e.g. 
			// using afUberPod::TestUberPodTask as Dude
			
			if (fanSrc.size != newSrc.size)
				fanFile.out.writeChars(newSrc.join("\n")).flush.close
		}
	}

	private Void explodePods() {
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
				if (podZip.contents[`/meta.props`].readProps["pod.docSrc"] != "true")
					build.log.warn("$podName has NO src files!")

				podZip.contents.each |file, uri| {
					if (uri.path.first != "src")				return
					if (uri.basename.endsWith("Test"))			return	// sometimes test code sneaks in with the source!
					if (uri.basename.startsWith("Test"))		return	// sometimes test code sneaks in with the source!
					uberDstDir := uberPodDir + uri.relTo(`/src/`)
					file.copyTo(uberDstDir)
					uberSrcDirs.add(uberDstDir.uri.relTo(build.scriptDir.uri).parent)
				}
			} finally
				podZip.close
		}
	}
}

internal const class SystemPods {
	private const Str[] sysPodNames			:= "docDomkit docIntro docLang docFanr docTools build compiler compilerDoc compilerJava compilerJs concurrent dom domkit email fandoc fanr fansh flux fluxText fwt gfx graphics inet obix sql syntax sys util web webfwt webmod wisp xml".lower.split
	private const Str[] skySparkPodNames	:= "arcbeam asn1 auth axon bacnet bacnetExt builderExt chart clusterMod codemirror connExt crypto debug def defc demoExt demogen devMod dict dictbase docFresco docgen docgfx docHaystack docSkySpark docTraining energyExt energyStarExt equipExt fileRepo folio folio3 folioStore fontMetrics fresco frescoRes ftp geoExt greenButtonExt haystack haystackExt hisExt hisKitExt hvacExt installMod ioExt javautil jobExt jssc kpiExt ldap legacy lightingExt mathExt mib migrate misc mlExt mobile modbusExt navMod noteExt obixExt opc opcExt pdf pdf2 ph phIct phIoT phScience pim pointExt projMod rdf replMod reportExt ruleExt scheduleExt sedona sedonaExt serialMod siteSparkExt skyarc skyarcd slf4j_nop smileCore snmpExt sparkExt sqlExt stackhub svg svggfx tariffExt templateHaystack tools ui uiBuilder uiDev uiFonts uiIcons uiMisc uiMod uiTest userMod vdom view view2 viz weatherExt xmlExt xqueryMod".lower.split

	Bool isSysPod(Str podName) {
		sysPodNames.contains(podName.lower)
	}

	Bool isSkyPod(Str podName) {
		skySparkPodNames.contains(podName.lower)
	}
}

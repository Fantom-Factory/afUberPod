using build::BuildPod
using build::Task

**
** pre>
** meta["afUberPod.pods"] = "afFom afEfan"
** <pre
** 
class UberPodTask : Task {
	private BuildPod	build
	private File		uberDir
	private Str[]		allPodNames
	private Str[]		uberPodNames
	private Uri[]		uberSrcDirs

	new make(BuildPod build) : super(script) {
		this.build			= build
		this.uberDir		= `buildy/afUberPod/`.toFile
		this.uberPodNames	= build.meta["afUberPod.pods"]?.split ?: Str#.emptyList
		this.uberSrcDirs	= Uri[,]
		this.allPodNames	= uberPodNames.dup.rw.add(build.podName)
	}

	override Void run() {
		uberDir.delete
		uberDir.create

		explodePods
		allPodNames.each { filterPodCode(it) }
		
		build.srcDirs = uberSrcDirs.unique
		build.depends = build.depends.exclude |dep| {
			uberPodNames.any { dep.startsWith(it) }
		}
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

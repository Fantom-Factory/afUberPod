using build::BuildPod
using build::Task

class UberPodTask : Task {
	
	Str? pods
	BuildPod? build

	** Construct the task
	** TODO Check the document conventions
	new make(BuildPod script) : super(script) {
		setPods
	}

	** Run the uberpod task
	override Void run() {
		log.info("afUberPod Task")
		createBuildDir
		copyProjectSrc
		copyPodFiles
		updateBuildDirs
	}

	// called from the constructor
	private Void setPods() {
		build = script as BuildPod
		meta := build.meta
		// check that the meta exists
		pods = meta.getChecked("afUberPod.pods")
	}

	// TODO This could be a temp dir - see test fandoc
	Void createBuildDir() {
		buildDir := File.os(".")
		buildDir.createDir("build/afUberPod/fan")
		// TODO See documentation can delete on exit etc
		// File.createTemp(prefix, suffix, dir)
	}

	** Project source should have any using statements that reference
	** a contained pod removed
  Void copyProjectSrc() {
		uberDir := `build/afUberPod/fan/`.toFile
		build.srcDirs.each |srcDirUri| {
			srcDirFile := srcDirUri.toFile
			// TODO: Change this copy operation to remove the using statements
			// copyTo(srcDirFile, uberDir.plus(srcDirUri), true)
			srcDirUri.toFile.listFiles.each |srcFile| {
				filterTextCopy(srcFile, uberDir.plus(srcFile.uri), "using")
			}
		}
	}

	Void copyPodFiles() {
		podArray := pods.split(',')
		podArray.each |podName| {
			pod := Env.cur.findPodFile(podName.toStr)
			log.debug("Pod: $pod")
			migratePod(pod)
		}
	}

	Void updateBuildDirs() {
		build := script as BuildPod
		log.info("Build source directories: $build.srcDirs")
		build.srcDirs = buildSrcDirs
		log.info("Build source directories: $build.srcDirs")
		build.resDirs = buildResDirs
		log.info("Build res directories: $build.resDirs")
	}

	private Uri[] buildSrcDirs() {
		srcDirs := [,]
		srcDirs.add(`build/afUberPod/fan/fan/`)
		podArray := pods.split(',')
		podArray.each |podName| {
			srcDirs.add(`build/afUberPod/fan/$podName/fan/`)
		}
		return srcDirs
	}

	private Uri[] buildResDirs() {
		resDirs := [,]
//		resDirs.add(`build/afUberPod/fan/res/`)
		podArray := pods.split(',')
		podArray.each |podName| {
			resDirs.add(`build/afUberPod/fan/$podName/res/`)
		}
		return resDirs
	}

	Void cleanup() {
		File.os("./build/afUberPod").delete
	}

	** Copies the given file to the destination.
	** Both 'from' and 'to' must either be directories, or not.
	Void copyTo(File from, File to, Obj? overwrite := null) {
		if (from.isDir.xor(to.isDir))
			throw IOErr("Both 'from' and 'to' must either be directories, or not.")
		from.copyTo(to, ["overwrite":overwrite])
	}

	** copy one file to another stripping header lines
	Void filterTextCopy(File from, File to, Str filterWord) {
		log.level = LogLevel.debug
		log.debug("Copying from: $from To: $to Filter: $filterWord")
		outFile := to.out(false)  // don't append
		from.eachLine |line| {
			if (!(line.startsWith(filterWord) && containsPodName(line))) {
				outFile.printLine(line)
				log.debug(line)
			}
		}
		outFile.close
	}

	private Bool containsPodName(Str line) {
		log.debug("pods $pods line $line")
		podArray := pods.split(',')
		Bool result := false
		podArray.each |podName| {
			if (line.contains(podName))
				result = true
			log.debug("[line: $line, podName: $podName, match: $result]")
		}
		return result
	}

	** Copy the source files and the resources
	** Source files end in fan
	** Resource files are in the res folder
	private Void migratePod(File pod) {
		zip := Zip.open(pod)
		podName := pod.basename
		uberDir := "build/afUberPod/fan/$podName/"
		srcDest := "$uberDir/fan/".toUri.toFile // for fan files
		resDest := "$uberDir/res/".toUri.toFile
		srcDest.create
		resDest.create

		zip.contents.each |f| {
			if (f.isDir) return

			if (f.ext == "fan") {
				Str filterWord := "using"
				bn := f.basename + ".fan"
				File to := srcDest.plus(bn.toUri)
				log.level = LogLevel.debug
				log.debug("Copying from: $f To: $to Filter: $filterWord")
				outFile := to.out(false)  // don't append
				f.eachLine |line| {
					if (!(line.startsWith(filterWord) && containsPodName(line))) {
						outFile.printLine(line)
						log.debug(line)
					}
				}
				outFile.close
			}
			else if (f.pathStr == "res") {
				f.copyInto(resDest, ["overwrite":true])
			}
		}
	}
}

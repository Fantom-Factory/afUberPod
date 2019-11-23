using build::BuildPod

class Build : BuildPod {

	new make() {
		podName = "afUberPod"
		summary = "My Awesome afUberPod Project"
		version = Version("1.0")

		meta = [
			"pod.dis"		: "Uber Pod",
			"repo.tags"		: "system",
			"repo.public"	: "true",
		]

		depends = [
			"sys   1.0.70 - 1.0",
			"build 1.0.70 - 1.0",
			
			// ---- testing ----
			"concurrent 1.0.70 - 1.0",
		]

		srcDirs = [`fan/`, `test/`]
		resDirs = [`doc/`]

		docApi = true
		docSrc = true
		
		meta["afBuild.testPods"] = "concurrent"
	}
}

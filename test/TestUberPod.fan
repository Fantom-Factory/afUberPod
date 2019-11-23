using build::BuildPod

class TestUberPod : Test {
	
	// note it's better to have lots of smaller tests, rather than one big one
	// but in our case, it depends on how easy it is to set the tests up
	Void testStuff() {
		// do all the setup...
		
		build		:= MyBuildPod() {
			it.podName	= "afExplorer"
			it.depends	= ["sys 1.0", "afConcurrent 1.0"]
			it.meta	= [
				"afBuild.uberPod"	: "afConcurrent afBeanUtils"
			]
		}
		
		myEnv		:= MyEnvStub([
			"afConcurrent"	: PodFileStub("afConcurrent") {
				it.depends	= [Depend("afBeanUtils 1.0")]
				it.srcFiles	= [
					MyFileStub.makeStub(`/src/ConMon.fan`, "using afBeanUtils\n\nclass ConMon { ... }")
				]
			},
			"afBeanUtils"	: PodFileStub("afBeanUtils") {  },
		])
		
		// run the UberPod task
		uberTask	:= UberPodTask(build, myEnv)
		uberTask.run


		// check the results
		
		verifyEq(MyEnvStub.cur.logs[0], "Copied ConMon.fan to build/afUberPod/afConcurrent/ConMon.fan")
		
		// afConcurrent should have been uber'ed into the build, hence no longer be a dependency
		verifyFalse(build.depends.contains("afConcurrent 1.0"))
		
		verifyEq(build.meta["afBuild.uberPod.bundled"], "afConcurrent 1.0; afBeanUtils 1.0")
	}
}


class MyBuildPod : BuildPod { }
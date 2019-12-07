using build::BuildPod

class TestUberPod : Test {

	// Test Basic Functionality :: afReflux -> sys + afBeansUtils + afConcurrent
	//   1 - Build afReflux
	//   2 - Verify that no source was copied from sys
	//   3 - Verify that afBeansUtils + afConcurrent source directories has been added to build.srcDirs
	//   4 - Verify that afBeansUtils + afConcurrent has been removed from pod depednencies
	//   5 - Check "afBuild.uberPod.bundled" meta.
	Void testBasic() {
		//  Create our ubered POD: afReflux
		build		:= MyBuildPod() {
			it.podName	= "afReflux"
			it.depends	= ["sys 1.0"]
			it.meta	= [
				"afBuild.uberPod"	: "afConcurrent afBeanUtils"
			]
		}
		
		//Stub out our dependent pods; sys, afConcurrent and afBeansUtils
		myEnv		:= MyEnvStub([
			"afConcurrent"	: PodFileStub("afConcurrent") {
				it.srcFiles	= [
					MyFileStub.makeStub(`/src/ConMon.fan`),
					MyFileStub.makeStub(`/src/ConMon2.fan`)
				]
			},
			"afBeanUtils"	: PodFileStub("afBeanUtils") {  
				it.srcFiles = [
					MyFileStub.makeStub(`/src/afBeanFile01.fan`)
				]
			},
			"sys"	: PodFileStub("sys") {  
				it.srcFiles = [
					MyFileStub.makeStub(`/src/sysFile01.fan`)
				]
			},
		])
		
		// run the UberPod task
		uberTask	:= UberPodTask(build, myEnv)
		uberTask.run
		
		// Verify that the sys fan file 'sysFile01.fan' was not copied.
		verifyFalse(MyEnvStub.cur.logs.contains("Copied sysFile01.fan to build/afUberPod/sys/sysFile01.fan"))

		//Verify that the source files for afBeansUtils + afConcurrent has been added to 'build.srcDirs'
		verifyEq(build.srcDirs, [`build/afUberPod/afConcurrent/`, `build/afUberPod/afBeanUtils/`])
		
		//Verify that all of our source files has been copied over.
		verifyTrue(MyEnvStub.cur.logs.contains("Copied ConMon.fan to build/afUberPod/afConcurrent/ConMon.fan"))
		verifyTrue(MyEnvStub.cur.logs.contains("Copied ConMon2.fan to build/afUberPod/afConcurrent/ConMon2.fan"))
		verifyTrue(MyEnvStub.cur.logs.contains("Copied afBeanFile01.fan to build/afUberPod/afBeanUtils/afBeanFile01.fan"))

		//Verfy that our dependencies are correct
		verifyFalse(build.depends.contains("afBeanUtils 1.0"))
		verifyFalse(build.depends.contains("afConcurrent 1.0"))
		verifyTrue(build.depends.contains("sys 1.0"))

		//Verify that our meta.props 'afBuild.uberPod.bundled is correct'
		verifyEq(build.meta["afBuild.uberPod.bundled"], "afConcurrent 1.0; afBeanUtils 1.0")
	}
	
	//Test Transative Functionality :: afExplorer -> sys + afReflux
	// Where, afReflux depends on afBeansUtils and afConcurrent
	//  1 - Verify that the source file for afRefulx has been copied properly
	//	2 - Verify that the source file for the transative dependencies (afConcurrent and afBeanUtils) has been copied.
	//	3 - Verify that the source file for sys has not been copied over
	//  4 - Verify that afReflux, afConcurrent, and afBeanUtils has been added to build.srcDirs
	//  5 - Verify that appropraite dependencie has been removed from main afExplorer dependancy list.
	//	6 - Check "afBuild.uberPod.bundled" meta.s
	Void testTransitive() {
		//  Create our ubered POD: afReflux
		build		:= MyBuildPod() {
			it.podName	= "afExplorer"
			it.depends	= ["sys 1.0", "afReflux 1.0"]
			it.meta	= [
				"afBuild.uberPod"	: "afReflux"  //Check afBeanUtils/afBeanFile02.fan in meta, verify that it only brings in that file
			]
		}
		
		//Stub out our dependent pods; sys, afConcurrent and afBeansUtils
		myEnv		:= MyEnvStub([
			"afReflux"	: PodFileStub("afReflux") {
				it.depends	= [Depend("afBeanUtils 1.0"), Depend("afConcurrent 1.0")]
				it.srcFiles	= [
					MyFileStub.makeStub(`/src/afRefluxFile01.fan`)
				]
			},
			"afBeanUtils"	: PodFileStub("afBeanUtils") {  
				it.srcFiles = [
					MyFileStub.makeStub(`/src/afBeanFile01.fan`)
				]
			},
			"afConcurrent"	: PodFileStub("afConcurrent") {  
				it.srcFiles = [
					MyFileStub.makeStub(`/src/ConMon.fan`, "using afBeanUtils\n\nclass ConMon { ... }"),
					MyFileStub.makeStub(`/src/ConMon2.fan`)
				]
			},
			"sys"	: PodFileStub("sys") {  
				it.srcFiles = [
					MyFileStub.makeStub(`/src/sysFile01.fan`)
				]
			},
		])
		
		// run the UberPod task
		uberTask	:= UberPodTask(build, myEnv)
		uberTask.run
		
		// Verify that the source file for afRefulx has been copied properly.
		verifyTrue(MyEnvStub.cur.logs.contains("Copied afRefluxFile01.fan to build/afUberPod/afReflux/afRefluxFile01.fan"))
		
		// Verify that the source files for the transitive POD's has been copied properly.
		verifyTrue(MyEnvStub.cur.logs.contains("Copied afBeanFile01.fan to build/afUberPod/afBeanUtils/afBeanFile01.fan"))
		verifyTrue(MyEnvStub.cur.logs.contains("Copied ConMon.fan to build/afUberPod/afConcurrent/ConMon.fan"))
		verifyTrue(MyEnvStub.cur.logs.contains("Copied ConMon2.fan to build/afUberPod/afConcurrent/ConMon2.fan"))

		//Verify that the source files for the sys POD has not been copied over.
		verifyFalse(MyEnvStub.cur.logs.contains("Copied sysFile01.fan to build/afUberPod/sys/sysFile01.fan"))

		//Verfiy that the source files for afReflux, afConcurrent, and afBeanUtils has been added to build.srcDirs
		verifyEq(build.srcDirs, [`build/afUberPod/afReflux/`, `build/afUberPod/afBeanUtils/`, `build/afUberPod/afConcurrent/`])

		// Verify the contents of build.depends
		verifyFalse(build.depends.contains("afReflux 1.0"))  //TODO: add in false for afConcurrent and afBeanUtils
		verifyTrue(build.depends.contains("sys 1.0"))

		//Verify that our meta.props 'afBuild.uberPod.bundled is correct'
		verifyEq(build.meta["afBuild.uberPod.bundled"], "afReflux 1.0; afBeanUtils 1.0; afConcurrent 1.0")
	}
}


class MyBuildPod : BuildPod { }

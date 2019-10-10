using build

/*
We can assume src code is held within the pods. 
(It may be nice to have a separate src dir for each pod) 
update the BuildPod.srcDirs to contain the new src dirs, which replace the old ones 
in a similar way, the BuildPod.resDirs would also need to be copied and updated. 
*/
class TestUberPodTask : Test {

	UberPodTask? task
	
	override Void setup() {
		// To run these tests the pod needs to be available
		// This doesn't work we can only test from file system
		// testBuildScript := `fan://afUberPod/res/test/TestBuild.fan`.get
		testBuildScript := `res/test/TestBuild.fan`.toFile
		buildType	:= Env.cur.compileScript(testBuildScript)

		//build := BuildPod()
		//build.srcDirs

		build	:= buildType.make
		task = UberPodTask(build)
	}

	override Void teardown() {
		Log log := Log.get("TestUberPodTask")
		log.info("*** DISABLED CLEANUP - MANUALLY DELETE BUILD FOLDER")
		//		task.cleanup()
	}
	
	// TODO: currently isolating this test
	Void testFilterCopy()  {
		`res/test/copysource.txt`.toFile.delete
		verifyFalse(`res/test/copysource.txt`.toFile.exists)
		task.filterTextCopy(`res/test/dummysrc.txt`.toFile, `res/test/copysource.txt`.toFile, "using")
		verify(`res/test/copysource.txt`.toFile.exists)
		// TODO check the contents of the copy
	}

	// copy over all the current Fantom source (see BuildPod.srcDirs) 
	Void testCopyProjectSrc() {
		// see BuildPod.srcDirs
		task.copyProjectSrc
		// verify()   
	}
	
	Void testMake() {
		verifyEq(task.pods, "afBeanUtils, afConcurrent")
		// verify the directories exist in the build folder
		// verify the source folders have been created
	}

	Void testCreateBuildDir() {
		// TODO Re-enable this
		//verifyFalse(File.os("./build/afUberPod").exists)
		task.createBuildDir
		verify(File.os("./build/afUberPod").exists)
	}

	//	copy over all the source code from within the pods mentioned in "afUberPod.pods". 
	// We can assume src code is held within the pods.
	// (It may be nice to have a separate src dir for each pod) 
	Void testPodSrcCopied() {
		// Given
		task.copyPodFiles()
		// Then - Verify
	}

	// update the BuildPod.srcDirs to contain the new src dirs, which replace the old ones
	Void testUpdateBuildDirs() {
		task.updateBuildDirs()
	}
// //	
// //	// in a similar way, the BuildPod.resDirs would also need to be copied and updated
// //	Void testPodResDirsUpdated() {
// //		fail("Pending implementation")
// //	}
// //	
// //	// all using statements that reference a contained pod will need to be deleted.
// //	// for expedience, these can be assumed to be one per line, and at the top of the .fan src file
// //	Void testAllUsingStatementsRemoved() {
// //		fail("Pending implementation")
// //	}
// //	
// //	// warn about using statements like using ClassA as ClassB
// //	Void testUsingAsStatements() {
// //		fail("Pending implementation")
// //	}
// //	
// //	// all fan file names should be unique across all src directories - warn if found
// //	Void testUniqueFanNames() {
// //		fail("Pending implementation")
// //	}
// //	
// //	// all class names should be unique across all fan src files - warn if found
// //	Void testUniqueClassNames() {
// //		fail("Pending")
// //	}
}

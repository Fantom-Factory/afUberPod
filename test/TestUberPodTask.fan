using build::BuildPod

class TestUberPodTask : Test {

	UberPodTask? task
	
	override Void setup() {
		this.task = UberPodTask(BuildPodStub {
			it.srcDirs = Uri[,]
		})
	}
}

internal class BuildPodStub : BuildPod {
	new make() : super() { }
}

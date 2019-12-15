using concurrent::Actor

class MyEnvStub : MyEnv {
	Str:PodFile	podFiles
	Str[]		logs	:= Str[,]
	
	new make(Str:PodFile podFiles) {
		this.podFiles = podFiles
		Actor.locals["afUberPod.testEnv"] = this
	}
	
	override PodFile findPodFile(Str podName) {
		podFiles[podName] ?: throw Err("Can't find pod: $podName")
	}
	
	static MyEnvStub cur() {
		// I loathe this poor man's IoC
		// but this beats passing an Env var everywhere just for testing
		Actor.locals["afUberPod.testEnv"]
	}
}

class PodFileStub : PodFile {
	override Depend		asDepend
	override Depend[]	depends	
			MyFile[]	srcFiles

	new make(Str name) : super(null) {
		this.asDepend	= Depend("$name 1.0")
		this.depends	= Depend[,]
		this.srcFiles	= MyFile[,]
	}

	override Void open(|PodFile| fn) {
		fn(this)
	}

	override Bool hasSrcFiles() {
		srcFiles.size > 0
	}
	
	override Void eachSrcFile(|MyFile, Uri| fn) {
		srcFiles.each |file| { fn(file, file.file.uri) }
	}
}

class MyFileStub : MyFile {
	
	new make(File file) : super(file) { }
	
	static new makeStub(Uri loc, Str? content := "") {
		// create an in-memory file
		MyFileStub(content.toBuf.toFile(loc))
	}
	
	override Void write(Str content) { }
	override Void copyTo(MyDir to)	 {
		echo("$to.uri")
		MyEnvStub.cur.logs.add("Copied $name to $to.uri")
	}
}

class MyDirStub : MyDir {
	override Uri uri

	new make(Uri uri) : super(null) {
		this.uri = uri
	}
	
	@Operator
	override This plus(Uri path) {
		uri = uri + path
		return this
	}
	
	override MyFile[] listFiles() {
		if (this.uri == `/meh`)
			return MyFile[,]
		return MyFile[,]
	}
	
	override Void create() { }
	override Void delete() { }
}

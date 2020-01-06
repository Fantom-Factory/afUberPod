
class MyEnv {
	virtual PodFile findPodFile(Str podName) {
		PodFile(Env.cur.findPodFile(podName))
	}
}

class PodFile {
	private File? 		podFile	// nullable for PodFileStub
	public [Str:Str]	podMeta := [:]
	private [Uri:File]?	contents

	new make(File? podFile) {
		this.podFile = podFile
	}

	virtual Depend[] depends() {
		podDepends := podMeta["pod.depends"]?.trimToNull	// sys has no dependencies!
		return podDepends == null ? Depend#.emptyList : podDepends.split(';').map { Depend(it) }
	}

	virtual Bool hasSrcFiles() {
		podMeta["pod.docSrc"] != "true"
	}

	virtual Depend asDepend() {
		Depend(podMeta["pod.name"] + " " + podMeta["pod.version"])
	}

	virtual Obj? open(|PodFile->Obj?| fn) {
		// should really move close to a finally - meh
		res := null
		Zip.open(podFile) {
			this.contents	= it.contents
			this.podMeta	= it.contents[`/meta.props`].readProps
			res = fn(this)
		}.close
		return res
	}

	virtual Void eachSrcFile(|MyFile, Uri| fn) {
		contents.each |file, uri| {
			if (uri.path.first != "src")			return
			if (uri.basename.endsWith("Test"))		return	// sometimes (in dev pods) test code sneaks in with the source!
			if (uri.basename.startsWith("Test"))	return	// sometimes (in dev pods) test code sneaks in with the source!
			fn(MyFile(file), uri)
		}
	}
}

class MyFile {
	File file

	new make(File file) {
		this.file = file
	}

	virtual Str[] readAllLines(){
		file.readAllLines
	}

	virtual Str name() {
		file.name
	}

	virtual Str ext() {
		file.ext
	}

	virtual Void write(Str content) {
		file.out.writeChars(content).flush.close
	}

	virtual Void copyInto(MyDir to) {
		file.copyInto(to.file)
	}

	override Str toStr() {
		file.toStr
	}
}

class MyDir {
	File? file		// nullable for MyFileStub

	new make(Uri? uri) {
		this.file = uri?.toFile
	}

	@Operator
	virtual This plus(Uri path) {
		MyDir((file + path).uri)
	}

	virtual MyFile[] listFiles() {
		file.listFiles.map { MyFile(it) }
	}

	virtual Uri uri() {
		file.uri
	}

	virtual Void create() {
		file.create
	}

	virtual Void delete() {
		file.delete
	}

	virtual Void createDir(Str dirName) {
		file.createDir(dirName)
	}

	override Str toStr() {
		file?.toStr ?: "null"
	}
}

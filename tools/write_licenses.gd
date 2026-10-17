extends SceneTree
func _initialize() -> void:
	var content:String=Engine.get_license_text()+"\n\nTHIRD-PARTY COMPONENTS\n\n"
	for component in Engine.get_copyright_info():
		content+=str(component.name)+"\n"
		for part in component.parts:
			content+="Files: "+str(part.files)+"\nCopyright: "+str(part.copyright)+"\nLicense: "+str(part.license)+"\n\n"
	var licenses:Dictionary=Engine.get_license_info()
	for key in licenses:content+="\n"+str(key)+"\n\n"+str(licenses[key])+"\n"
	for path in ["res://assets/GODOT-LICENSE.txt","res://builds/GODOT-LICENSE.txt"]:
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(content)
	quit()

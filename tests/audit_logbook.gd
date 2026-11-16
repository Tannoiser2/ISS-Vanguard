extends SceneTree
## Diagnostica: passa tutte le istruzioni del Logbook all'interprete e scrive che cosa riconosce
## e che cosa resta. godot --headless --path . -s res://tests/audit_logbook.gd -- <uscita.json>

func _initialize() -> void:
	var out := []
	for camp in [8, 12, 14]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/logbook/c%d.json" % camp))
		for k in d["logs"]:
			var a: Dictionary = d["logs"][k]
			for vk in a.get("verses", {}):
				for el in a["verses"][vk].get("e", []):
					for c in el.get("c", []):
						var r := str(c.get("r", ""))
						if r == "":
							continue
						var an: Dictionary = Effetti.analizza_it(r)
						out.append({"camp": camp, "n": int(a.get("n", 0)), "r": r, "ops": an["op"], "resto": an["resto"]})
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("istruzioni: ", out.size())
	quit()

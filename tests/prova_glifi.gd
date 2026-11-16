extends SceneTree
## I simboli usati dall'interfaccia devono esistere nei font del gioco (con le loro riserve), senza contare
## sui font del sistema: nel browser e su iPad non ci sono, e i simboli diventano quadratini.
## godot --headless --path . -s res://tests/prova_glifi.gd

func _ha(f: Font, c: int) -> bool:
	if f == null:
		return false
	var base: Font = f.base_font if f is FontVariation else f
	if base is FontFile and base.has_char(c):
		return true
	for fb in base.fallbacks:
		if _ha(fb, c):
			return true
	return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var T = root.get_node("Tema")
	var simboli := "→▶●✕⚙➜☠◀≡◆✔■▸○⌂⟲⟳◎✝✓✚★⋯∞▾↺⟨⟩•—…«»àèéìòù"
	var errori := 0
	for nome in ["testo", "testo_corsivo", "testo_grassetto", "testo_grassetto_corsivo", "mono", "titolo", "titolo_forte"]:
		var manca := ""
		for i in simboli.length():
			if not _ha(T.get(nome), simboli.unicode_at(i)):
				manca += simboli[i]
		print(("  ok   " if manca == "" else "  ERRORE ") + nome + ((": mancano " + manca) if manca != "" else ": tutti i simboli presenti"))
		if manca != "":
			errori += 1
	print("ERRORI: %d" % errori)
	quit(1 if errori > 0 else 0)

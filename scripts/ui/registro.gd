## Registro di bordo: codice della campagna, flag del Logbook, annotazioni visitate, diario e note.
class_name Registro
extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var vel := ColorRect.new()
	vel.color = Color(0, 0.01, 0.03, 0.85)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vel)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 120
	p.offset_right = -120
	p.offset_top = 70
	p.offset_bottom = -50
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(Tema.etichetta("REGISTRO DI BORDO", 22, Tema.TESTO, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(Tema.pulsante("✕ CHIUDI", queue_free, 13))
	var cod := Tema.testo_ricco(18)
	cod.text = "Campagna [b]%s[/b] · %s · modalità %s · [color=#4fd1ff][font_size=24]codice [b]%s[/b][/font_size][/color]  (per riprenderla da un altro dispositivo)" % [
		Campagna.dati.get("nome", ""), Dati.CAMPAGNE[Campagna.id_campagna()]["nome"], Campagna.dati.get("modo", ""), Campagna.codice()]
	v.add_child(cod)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_scheda_flag())
	tabs.add_child(_scheda_visitate())
	tabs.add_child(_scheda_diario())
	tabs.add_child(_scheda_note())

func _scheda_flag() -> Control:
	var s := ScrollContainer.new()
	s.name = "FLAG DEL LOGBOOK"
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(v)
	var nota := Label.new()
	nota.text = "Caselle (A, B, C…) segnate nelle annotazioni. Si segnano da sole con le scelte; qui si possono correggere a mano, a tuo rischio come nell'app."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_color_override("font_color", Tema.TESTO_2)
	v.add_child(nota)
	var m := Campagna.motore
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 24)
	v.add_child(g)
	var tutte := []
	for id_log in Dati.logbook(m.camp).get("logs", {}):
		var a: Dictionary = Dati.logbook(m.camp)["logs"][id_log]
		for f in a.get("flags", []):
			tutte.append([int(a.get("n", 0)), int(f[0]), str(f[1])])
	tutte.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[2] < b[2]))
	var solo_segnati := CheckBox.new()
	solo_segnati.text = "Mostra solo quelli segnati"
	solo_segnati.button_pressed = true
	v.move_child(solo_segnati, 1)
	var riempi := func():
		for c in g.get_children():
			c.queue_free()
		for t in tutte:
			if solo_segnati.button_pressed and m.flag(t[1]) != 1:
				continue
			var cb := CheckBox.new()
			cb.text = "Annotazione %s" % t[2]
			cb.button_pressed = m.flag(t[1]) == 1
			cb.toggled.connect(func(on):
				m.imposta_flag(t[1], 1 if on else 0)
				Campagna.modificata())
			g.add_child(cb)
		if g.get_child_count() == 0:
			var l := Label.new()
			l.text = "Nessuna casella segnata."
			g.add_child(l)
	solo_segnati.toggled.connect(func(_on): riempi.call())
	riempi.call()
	var altri := m.flag_segnati().size()
	var l2 := Label.new()
	l2.text = "Flag interni segnati in tutto (anche quelli che il Logbook non mostra): %d" % altri
	l2.add_theme_color_override("font_color", Tema.TESTO_2)
	v.add_child(l2)
	return s

func _scheda_visitate() -> Control:
	var s := ScrollContainer.new()
	s.name = "ANNOTAZIONI VISITATE"
	var r := Tema.testo_ricco(18)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vis: Dictionary = Campagna.motore.stato.get("visitate", {})
	var nums := []
	for k in vis:
		nums.append(int(k))
	nums.sort()
	r.text = ", ".join(nums.map(func(x): return str(x))) if not nums.is_empty() else "Nessuna."
	s.add_child(r)
	return s

func _scheda_diario() -> Control:
	var s := ScrollContainer.new()
	s.name = "DIARIO"
	var r := Tema.testo_ricco(17)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ev: Array = Campagna.dati.get("registro", {}).get("eventi", [])
	var righe := []
	for i in range(ev.size() - 1, -1, -1):
		righe.append("[color=#9fbbd6]%s[/color]  %s" % [str(ev[i][0]).substr(0, 16).replace("T", " "), ev[i][1]])
	r.text = "\n".join(righe)
	s.add_child(r)
	return s

func _scheda_note() -> Control:
	var v := VBoxContainer.new()
	v.name = "NOTE"
	var t := TextEdit.new()
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.text = str(Campagna.dati.get("registro", {}).get("note", ""))
	t.placeholder_text = "Appunti della campagna: pianeti registrati, risorse, cose da ricordare…"
	t.add_theme_font_override("font", Tema.testo)
	t.text_changed.connect(func():
		Campagna.dati["registro"]["note"] = t.text
		Campagna.modificata())
	v.add_child(t)
	return v

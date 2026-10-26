## Menu principale: nuova campagna, campagne salvate, ripresa con codice, regole.
class_name Menu
extends Control

signal inizia

var _lista: VBoxContainer
var _stato: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	# sfondo: copertina della campagna con velatura
	var bg := TextureRect.new()
	bg.texture = load("res://assets/app/copertine/8_cover.webp")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var vel := ColorRect.new()
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := ShaderMaterial.new()
	sh.shader = Shader.new()
	sh.shader.code = """shader_type canvas_item;
void fragment(){
	float x = UV.x;
	float a = mix(0.93, 0.25, smoothstep(0.25, 0.9, x));
	vec3 c = mix(vec3(0.01,0.03,0.08), vec3(0.03,0.02,0.06), UV.y);
	float riga = 0.03 * step(0.5, fract(UV.y * 360.0));
	COLOR = vec4(c, a + riga);
}"""
	vel.material = sh
	add_child(vel)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 70)
	add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 60)
	m.add_child(h)
	var sx := VBoxContainer.new()
	sx.custom_minimum_size = Vector2(560, 0)
	sx.add_theme_constant_override("separation", 14)
	h.add_child(sx)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/splash.png")
	logo.custom_minimum_size = Vector2(560, 260)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	sx.add_child(logo)
	var sub := Tema.testo_ricco(18)
	sub.text = "[color=#9fbbd6]Campagna in solitario · Logbook italiano con tutte le scelte e i flag · tavolo 3D con i componenti del gioco · salvataggi online[/color]"
	sx.add_child(sub)
	sx.add_child(_spazio(16))
	sx.add_child(_largo(Tema.pulsante_primario("NUOVA CAMPAGNA", _nuova, 20)))
	sx.add_child(_largo(Tema.pulsante("RIPRENDI CON UN CODICE", _codice, 18)))
	sx.add_child(_largo(Tema.pulsante("CARICA DA UN FILE", _carica_file, 18)))
	sx.add_child(_largo(Tema.pulsante("REGOLAMENTO", _regole, 18)))
	if not OS.has_feature("web"):
		sx.add_child(_largo(Tema.pulsante("ESCI", func(): get_tree().quit(), 18)))
	_stato = Label.new()
	_stato.add_theme_color_override("font_color", Tema.AMBRA)
	_stato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sx.add_child(_stato)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sx.add_child(fill)
	var cr := Label.new()
	cr.text = "ISS Vanguard © Awaken Realms. Adattamento per uso personale; testi dall'app ufficiale ISS Vanguard Companion,\ncomponenti dal modulo Tabletop Simulator. Font Orbitron, Exo 2, Share Tech Mono (SIL OFL)."
	cr.add_theme_font_size_override("font_size", 12)
	cr.add_theme_color_override("font_color", Color(0.6, 0.68, 0.78))
	sx.add_child(cr)
	# campagne salvate
	var dx := PanelContainer.new()
	dx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dx.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dx.custom_minimum_size = Vector2(0, 300)
	h.add_child(dx)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	dx.add_child(dv)
	dv.add_child(Tema.etichetta("CAMPAGNE SALVATE SU QUESTO DISPOSITIVO", 15, Tema.CIANO))
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 6)
	dv.add_child(_lista)
	_aggiorna_lista()

func _spazio(hh: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hh)
	return c

func _largo(b: Button) -> Button:
	b.custom_minimum_size = Vector2(420, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b

func _aggiorna_lista() -> void:
	for c in _lista.get_children():
		c.queue_free()
	var el := Campagna.elenco_locale()
	if el.is_empty():
		var l := Label.new()
		l.text = "Nessuna campagna salvata. Inizia una nuova campagna, oppure riprendine una con il suo codice."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Tema.TESTO_2)
		_lista.add_child(l)
		return
	for x in el:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var b := Tema.pulsante("", func():
			if Campagna.carica_locale(x["codice"]):
				inizia.emit(), 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var data := Time.get_datetime_string_from_unix_time(int(x["aggiornata"]) + _fuso(), true).substr(0, 16)
		b.text = "%s   ·   %s   ·   %s   ·   %s" % [x["nome"], Dati.CAMPAGNE.get(x["camp"], {}).get("nome", ""), x["codice"], data]
		r.add_child(b)
		var sc := Tema.pulsante("⤓", func(): _scarica(str(x["codice"]), str(x["nome"])), 14)
		sc.tooltip_text = "Scarica il salvataggio in un file (copia di sicurezza)"
		r.add_child(sc)
		var cp := Tema.pulsante("↺", func(): _copie(str(x["codice"]), str(x["nome"])), 14)
		cp.tooltip_text = "Copie di sicurezza: torna a una versione precedente"
		r.add_child(cp)
		var d := Tema.pulsante("✕", func():
			_conferma("Eliminare la copia locale di \"%s\"? (La copia online resta: si riprende con il codice %s.)" % [x["nome"], x["codice"]], func():
				Campagna.elimina_locale(x["codice"])
				_aggiorna_lista()), 14)
		d.tooltip_text = "Elimina dal dispositivo"
		r.add_child(d)
		_lista.add_child(r)

## Scarica il salvataggio in un file .json (nel browser come download, sul computer con una finestra).
func _scarica(cod: String, nome: String) -> void:
	var testo := Campagna.esporta(cod)
	if testo == "":
		_stato.text = "Salvataggio non trovato"
		return
	var nome_f := "ISS-Vanguard_%s_%s.json" % [cod, Time.get_date_string_from_system()]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(testo.to_utf8_buffer(), nome_f, "application/json")
		_stato.text = "Salvataggio di \"%s\" scaricato (%s)" % [nome, nome_f]
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.current_file = nome_f
	fd.filters = PackedStringArray(["*.json ; Salvataggio ISS Vanguard"])
	fd.file_selected.connect(func(p):
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f:
			f.store_string(testo)
			f.close()
			_stato.text = "Salvataggio scritto in %s" % p
		else:
			_stato.text = "Non riesco a scrivere %s" % p)
	add_child(fd)
	fd.popup_centered(Vector2i(900, 600))

var _cb_file: JavaScriptObject

## Carica una campagna da un file .json scaricato prima.
func _carica_file() -> void:
	if OS.has_feature("web"):
		_cb_file = JavaScriptBridge.create_callback(func(args): _file_letto(str(args[0])))
		JavaScriptBridge.get_interface("window").issFileLetto = _cb_file
		JavaScriptBridge.eval("""(function(){var i=document.createElement('input');i.type='file';i.accept='.json,application/json';
			i.onchange=function(){var f=i.files[0];if(!f)return;var r=new FileReader();r.onload=function(){window.issFileLetto(r.result);};r.readAsText(f);};
			i.click();})();""", true)
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.json ; Salvataggio ISS Vanguard"])
	fd.file_selected.connect(func(p): _file_letto(FileAccess.get_file_as_string(p)))
	add_child(fd)
	fd.popup_centered(Vector2i(900, 600))

func _file_letto(testo: String) -> void:
	if Campagna.importa(testo):
		inizia.emit()
	else:
		_stato.text = "Il file non è un salvataggio di ISS Vanguard"

## Copie di sicurezza di una campagna: si sceglie a quale tornare.
func _copie(cod: String, nome: String) -> void:
	var copie := Campagna.elenco_copie(cod)
	var d := AcceptDialog.new()
	d.title = "Copie di sicurezza di \"%s\"" % nome
	d.ok_button_text = "Chiudi"
	var v := VBoxContainer.new()
	var l := Label.new()
	l.text = "Il gioco tiene una copia della campagna ogni volta che la apri (le ultime %d).\nScegli a quale versione tornare: quella attuale resta fra le copie." % Campagna.MAX_COPIE if not copie.is_empty() else "Nessuna copia di sicurezza per questa campagna (si crea la prima volta che la apri)."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	v.add_child(l)
	for c in copie:
		var quando := Time.get_datetime_string_from_unix_time(int(c["quando"]) + _fuso(), true).substr(0, 16)
		var f: String = c["file"]
		var torna := func():
			if Campagna.ripristina_copia(f):
				inizia.emit()
			else:
				_stato.text = "Copia non leggibile"
		v.add_child(Tema.pulsante("Torna alla copia del %s" % quando, func():
			d.queue_free()
			_conferma("Tornare alla copia del %s di \"%s\"?" % [quando, nome], torna), 14))
	d.add_child(v)
	add_child(d)
	d.popup_centered(Vector2i(620, 0))

func _fuso() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

func _conferma(t: String, cb: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = t
	d.ok_button_text = "Sì"
	d.cancel_button_text = "No"
	d.confirmed.connect(cb)
	add_child(d)
	d.popup_centered(Vector2i(640, 0))

func _nuova() -> void:
	var p := NuovaCampagna.new()
	p.confermata.connect(func(camp, nome, modo):
		Campagna.nuova(camp, nome, modo)
		inizia.emit())
	add_child(p)

func _codice() -> void:
	var d := AcceptDialog.new()
	d.title = "Riprendi con un codice"
	d.ok_button_text = "Riprendi"
	var v := VBoxContainer.new()
	var l := Label.new()
	l.text = "Codice della campagna (6 caratteri, lo trovi nel registro di bordo):"
	v.add_child(l)
	var e := LineEdit.new()
	e.max_length = 6
	e.placeholder_text = "ABC123"
	v.add_child(e)
	d.add_child(v)
	d.confirmed.connect(func():
		var c := e.text.strip_edges().to_upper()
		if c.length() != 6:
			_stato.text = "Il codice ha 6 caratteri."
			return
		_stato.text = "Cerco la campagna %s online…" % c
		var ok: bool = await Campagna.carica_online(c)
		if ok:
			inizia.emit()
		elif Campagna.carica_locale(c):
			inizia.emit()
		else:
			_stato.text = "Campagna %s non trovata (%s)." % [c, Net.ultimo_errore if Net.ultimo_errore != "" else "codice inesistente"])
	add_child(d)
	d.popup_centered(Vector2i(520, 0))
	e.grab_focus()

func _regole() -> void:
	add_child(VisoreRegole.new())

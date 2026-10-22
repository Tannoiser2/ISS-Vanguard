## Plancia del pianeta in 3D: la plancia stampata sul tavolo, le carte PDI sui settori, le miniature
## della Squadra di Sbarco, i segnalini delle Minacce in piedi, il Lander e i segnalini di attrezzatura.
## Tasto sinistro: clic su un settore / trascina per spostare la vista; tasto destro: ruota;
## rotellina: zoom verso il cursore; tasto centrale: sposta.
class_name Plancia3D
extends Control

signal cliccato(n: int)

const SOGLIA := 6.0
const W := 20.0              # larghezza della plancia in unità 3D
const ALTEZZA_MINI := 1.05

var mis                      # Missione
var _vpc: SubViewportContainer
var _vp: SubViewport
var _mondo: Node3D
var camera: Camera3D
var D := W / 2.0121          # profondità (dipende dalle proporzioni dell'immagine)
var _tavola: MeshInstance3D
var _mat_tavola: StandardMaterial3D
var _bordo_tavola: MeshInstance3D
var _settori := {}           # n -> {"nodo", "fill", "mat_fill", "cornice", "mat_cornice", "carta", "mat_carta", "pdi", "info"}
var _pedine := {}            # chiave -> Node3D
var _mesh := {}
var _sopra := -1

var _cam_t := Vector3.ZERO
var _cam_d := 22.0
var _cam_y := 0.0
var _cam_p := 58.0
var _orbita := false
var _pan := false
var _premuto := false
var _premuto_pos := Vector2.ZERO
var _ultimo := Vector2.ZERO
var _tw_cam: Tween
var _nomi_visibili := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vpc = SubViewportContainer.new()
	_vpc.stretch = true
	_vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	_vpc.gui_input.connect(_input_vista)
	_vpc.mouse_exited.connect(func(): _hover(-1))
	add_child(_vpc)
	_vp = SubViewport.new()
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.handle_input_locally = false
	_vpc.add_child(_vp)
	_mondo = Node3D.new()
	_vp.add_child(_mondo)
	_ambiente()
	camera = Camera3D.new()
	camera.fov = 40
	camera.near = 0.1
	camera.far = 300
	_mondo.add_child(camera)
	_costruisci_tavola()
	_aggiorna_camera()
	# comandi della vista in alto a sinistra
	var h := HBoxContainer.new()
	h.position = Vector2(10, 8)
	h.add_theme_constant_override("separation", 6)
	add_child(h)
	for v in [["⌂", "Vista dall'alto", func(): vista_iniziale(true)], ["⟲", "Ruota a sinistra", func(): _ruota(-45)], ["⟳", "Ruota a destra", func(): _ruota(45)],
			["◎", "Inquadra il Membro attivo", _inquadra_attivo]]:
		var b := Tema.pulsante(v[0], v[2], 16)
		b.tooltip_text = v[1]
		b.custom_minimum_size = Vector2(40, 36)
		h.add_child(b)
	var aiuto := Label.new()
	aiuto.text = "Sinistro: scegli / trascina   Destro: ruota   Rotellina: zoom"
	aiuto.add_theme_font_size_override("font_size", 12)
	aiuto.add_theme_color_override("font_color", Color(0.62, 0.73, 0.84, 0.8))
	aiuto.add_theme_color_override("font_outline_color", Color.BLACK)
	aiuto.add_theme_constant_override("outline_size", 4)
	h.add_child(aiuto)

# ------------------------------------------------------------------ scena

func _ambiente() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.01, 0.02, 0.06)
	sm.sky_horizon_color = Color(0.05, 0.09, 0.18)
	sm.ground_bottom_color = Color(0.0, 0.0, 0.01)
	sm.ground_horizon_color = Color(0.05, 0.09, 0.18)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.66, 0.78)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.35
	we.environment = env
	_mondo.add_child(we)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-58, 30, 0)
	sole.light_energy = 0.62
	sole.shadow_enabled = true
	sole.directional_shadow_max_distance = 80
	_mondo.add_child(sole)
	var riemp := DirectionalLight3D.new()
	riemp.rotation_degrees = Vector3(-35, 210, 0)
	riemp.light_energy = 0.25
	riemp.light_color = Color(0.5, 0.75, 1.0)
	_mondo.add_child(riemp)

func _mat(col := Color.WHITE, trasp := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.75
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if trasp:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _costruisci_tavola() -> void:
	# piano scuro sotto la plancia
	var piano := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 90)
	piano.mesh = pm
	piano.position.y = -0.16
	var mp := _mat(Color(0.02, 0.035, 0.06))
	mp.metallic = 0.3
	piano.material_override = mp
	_mondo.add_child(piano)
	_bordo_tavola = MeshInstance3D.new()
	_bordo_tavola.material_override = _mat(Color(0.05, 0.07, 0.1))
	_mondo.add_child(_bordo_tavola)
	_tavola = MeshInstance3D.new()
	_mat_tavola = _mat(Color(0.35, 0.4, 0.45))
	_mat_tavola.roughness = 0.95
	_mat_tavola.metallic_specular = 0.0
	_tavola.material_override = _mat_tavola
	_mondo.add_child(_tavola)
	_dimensiona_tavola()

func _dimensiona_tavola() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(W, D)
	_tavola.mesh = pm
	var bm := BoxMesh.new()
	bm.size = Vector3(W + 0.3, 0.15, D + 0.3)
	_bordo_tavola.mesh = bm
	_bordo_tavola.position.y = -0.076

func imposta_plancia(t: Texture2D) -> void:
	if t == null:
		return
	var s := t.get_size()
	if s.y > 0:
		D = W * s.y / s.x
	_mat_tavola.albedo_texture = t
	_mat_tavola.albedo_color = Color(0.86, 0.86, 0.86)
	_dimensiona_tavola()
	for n in _settori:
		_settori[n]["nodo"].queue_free()
	_settori.clear()
	_crea_settori()
	vista_iniziale()
	aggiorna()

## Centro e dimensioni di un settore sulla plancia (in unità 3D).
func _rett(st: Dictionary) -> Rect2:
	var w := float(st.get("w", 0.2)) * W
	var h := float(st.get("h", 0.25)) * D
	var c := Vector2((float(st.get("x", 0.5)) - 0.5) * W, (float(st.get("y", 0.5)) - 0.5) * D)
	return Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h))

static func _v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)

func _crea_settori() -> void:
	if mis == null:
		return
	for st in mis.pl.get("settori", []):
		var n := int(st.get("n", 0))
		var r := _rett(st)
		var nodo := Node3D.new()
		nodo.position = _v3(r.get_center())
		_mondo.add_child(nodo)
		var fill := MeshInstance3D.new()
		var fm := PlaneMesh.new()
		fm.size = r.size
		fill.mesh = fm
		fill.position.y = 0.06
		var mf := _mat(Color(0, 0, 0, 0), true)
		fill.material_override = mf
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodo.add_child(fill)
		# cornice: quattro listelli
		var cornice := Node3D.new()
		var mc := _mat(Tema.CIANO, true)
		mc.emission_enabled = true
		mc.emission = Tema.CIANO
		for k in 4:
			var lst := MeshInstance3D.new()
			var b := BoxMesh.new()
			var orizz := k < 2
			b.size = Vector3(r.size.x + 0.08 if orizz else 0.08, 0.04, 0.08 if orizz else r.size.y)
			lst.mesh = b
			lst.material_override = mc
			lst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lst.position = Vector3(0 if orizz else (r.size.x / 2.0 if k == 2 else -r.size.x / 2.0), 0.07, (r.size.y / 2.0 if k == 0 else -r.size.y / 2.0) if orizz else 0.0)
			cornice.add_child(lst)
		cornice.visible = false
		nodo.add_child(cornice)
		# carta PDI piazzata sul settore
		var carta := MeshInstance3D.new()
		var mcarta := _mat()
		mcarta.metallic_specular = 0.05
		carta.material_override = mcarta
		carta.visible = false
		nodo.add_child(carta)
		var info := Label3D.new()
		info.font = Tema.mono
		info.font_size = 44
		info.pixel_size = 0.0006
		info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		info.fixed_size = true
		info.no_depth_test = true
		info.modulate = Tema.AMBRA
		info.outline_size = 12
		info.outline_modulate = Color(0, 0, 0, 0.9)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.position = Vector3(-r.size.x / 2.0 + 0.15, 0.5, -r.size.y / 2.0 + 0.25)
		info.offset = Vector2(0, 0)
		info.render_priority = 2
		nodo.add_child(info)
		var num := Label3D.new()
		num.text = str(n)
		num.font = Tema.titolo
		num.font_size = 64
		num.pixel_size = 0.006
		num.rotation = Vector3(-PI / 2, 0, 0)
		num.modulate = Color(1, 1, 1, 0.0)
		num.position = Vector3(r.size.x / 2.0 - 0.3, 0.09, -r.size.y / 2.0 + 0.3)
		nodo.add_child(num)
		_settori[n] = {"nodo": nodo, "rett": r, "fill": fill, "mat_fill": mf, "cornice": cornice, "mat_cornice": mc,
			"carta": carta, "mat_carta": mcarta, "pdi": "", "info": info, "num": num}

# ------------------------------------------------------------------ aggiornamento

func aggiorna() -> void:
	if mis == null or not is_inside_tree():
		return
	if _settori.is_empty():
		_crea_settori()
	var esp: Esplorazione = mis.esp
	var attivo := int(esp.s["attivo"]) if not esp.vivi().is_empty() else -1
	var sett_att := int(esp.membro(attivo)["settore"]) if attivo >= 0 else -1
	for n in _settori:
		var w: Dictionary = _settori[n]
		_aggiorna_carta(n, w, esp.pdi_in_cima(n))
		var sel: bool = int(n) == mis._sel and mis._cassetto_box.visible and mis._cassetto_tipo == "settore"
		var col := Color(0, 0, 0, 0)
		var bordo := Color(0, 0, 0, 0)
		if mis._scelta_settore:
			var ok: bool = mis._consentiti.has(int(n))
			col = Color(1, 0.7, 0.28, 0.16) if ok else Color(0, 0, 0, 0.55)
			bordo = Tema.AMBRA if ok else Color(0, 0, 0, 0)
		else:
			if int(n) == _sopra:
				col = Color(0.3, 0.8, 1.0, 0.10)
				bordo = Tema.CIANO
			if int(n) == sett_att:
				bordo = Tema.CIANO
			if sel:
				bordo = Tema.AMBRA
		w["mat_fill"].albedo_color = col
		w["cornice"].visible = bordo.a > 0
		w["mat_cornice"].albedo_color = bordo
		w["mat_cornice"].emission = bordo
		w["info"].text = _info(n)
	_aggiorna_pedine(esp, attivo)

func _info(n: int) -> String:
	var esp: Esplorazione = mis.esp
	if mis._scelta_settore and mis._consentiti.has(n):
		return ("➜ " + str(mis._consentiti[n])) if str(mis._consentiti[n]) != "" else "➜"
	var st: Dictionary = esp.s["settori"].get(str(n), {})
	var out := []
	if int(st.get("tempo", 0)) > 0:
		out.append("⧗%d" % int(st["tempo"]))
	for k in st.get("tracce", {}):
		out.append("▶%d" % int(st["tracce"][k]))
	if int(st.get("log", 0)) > 0 and not st.get("visitato", false):
		out.append("Log %d" % int(st["log"]))
	return "  ".join(out)

func _aggiorna_carta(n: int, w: Dictionary, id: String) -> void:
	if id == w["pdi"]:
		return
	w["pdi"] = id
	var carta: MeshInstance3D = w["carta"]
	carta.visible = false
	var c := Carte.per_id(id) if id != "" and id != "P000" else {}
	if not c.has("file"):
		return
	var r: Rect2 = w["rett"]
	Immagini.carica(str(c["file"]), func(t):
		if not is_instance_valid(carta) or w["pdi"] != id or t == null:
			return
		var s: Vector2 = t.get_size()
		var k: float = minf(r.size.x * 0.97 / s.x, r.size.y * 0.97 / s.y)
		var pm := PlaneMesh.new()
		pm.size = Vector2(s.x * k, s.y * k)
		carta.mesh = pm
		carta.position.y = 0.035
		w["mat_carta"].albedo_texture = t
		var sp: MeshInstance3D = carta.get_node_or_null("Spessore")
		if sp == null:
			sp = MeshInstance3D.new()
			sp.name = "Spessore"
			sp.material_override = _mat(Color(0.08, 0.09, 0.11))
			carta.add_child(sp)
		var bm := BoxMesh.new()
		bm.size = Vector3(s.x * k, 0.03, s.y * k)
		sp.mesh = bm
		sp.position.y = -0.016
		carta.visible = true)

## Le pedine sul tavolo: si creano, si spostano (con un saltello) e si tolgono quando spariscono.
func _aggiorna_pedine(esp: Esplorazione, attivo: int) -> void:
	var viste := {}
	var per_settore := {}      # n -> {"crew": [], "minacce": [], "token": []}
	for i in esp.vivi():
		per_settore.get_or_add(int(esp.membro(i)["settore"]), {}).get_or_add("crew", []).append(i)
	var conta := {}
	for m in esp.s["minacce"]:
		var sm := int(m.get("settore", 0))
		if sm > 0:
			var base := str(m.get("en", m.get("nome", "")))
			conta[base] = int(conta.get(base, 0)) + 1
			per_settore.get_or_add(sm, {}).get_or_add("minacce", []).append([m, "M:%s#%d" % [base, int(conta[base])]])
	for n in _settori:
		var r: Rect2 = _settori[n]["rett"]
		var c := r.get_center()
		var g: Dictionary = per_settore.get(int(n), {})
		var crew: Array = g.get("crew", [])
		for k in crew.size():
			var i: int = crew[k]
			var p := c + Vector2(-r.size.x * 0.08 + (k - (crew.size() - 1) / 2.0) * minf(0.95, r.size.x * 0.6 / max(1, crew.size())), r.size.y * 0.22)
			var chiave := "C%d" % i
			viste[chiave] = true
			var nodo := _pedina(chiave, func(): return _miniatura(esp.membro(i)))
			_metti(nodo, _v3(p))
			_evidenzia_attivo(nodo, i == attivo)
		var mn: Array = g.get("minacce", [])
		for k in mn.size():
			var chiave2: String = mn[k][1]
			viste[chiave2] = true
			var mm: Dictionary = mn[k][0]
			var nodo2 := _pedina(chiave2, func(): return _standee(mm))
			if nodo2.get_meta("file", "") != str(mm.get("file", "")):
				_aggiorna_standee(nodo2, mm)
			_metti(nodo2, _v3(c + Vector2(-r.size.x * 0.3 + k * 1.0, -r.size.y * 0.12)))
		if int(esp.s["lander"]["settore"]) == int(n):
			_nome_lander = str(esp.s["lander"].get("nome", ""))
			viste["L"] = true
			_metti(_pedina("L", _lander), _v3(c + Vector2(r.size.x * 0.3, -r.size.y * 0.2)))
		var st: Dictionary = esp.s["settori"].get(str(n), {})
		var tok: Array = st.get("attrezzature", [])
		for k in tok.size():
			var chiave3 := "E%s#%d" % [str(n), k]
			viste[chiave3] = true
			var tk: Dictionary = tok[k]
			var nodo3 := _pedina(chiave3, func(): return _gettone(Color(0.25, 0.8, 0.45), str(tk.get("nome", "")), 0.32))
			_metti(nodo3, _v3(c + Vector2(r.size.x * 0.4, r.size.y * 0.3 - k * 0.55)))
		var extra := []
		for k in int(st.get("segni", 0)):
			extra.append(["S", Color(1.0, 0.6, 0.15)])
		for k in int(st.get("droni", 0)):
			extra.append(["D", Color(0.55, 0.6, 0.7)])
		for k in int(st.get("germogli", 0)):
			extra.append(["G", Color(0.4, 0.8, 0.3)])
		for k in extra.size():
			var chiave4 := "X%s#%d%s" % [str(n), k, extra[k][0]]
			viste[chiave4] = true
			var colx: Color = extra[k][1]
			var tipo_x: String = extra[k][0]
			var nodo4 := _pedina(chiave4, func():
				if tipo_x == "D":
					return _sagoma("standee/drone.webp", "", Color.WHITE, Color(0.25, 0.28, 0.32), 0.45)
				if tipo_x == "G":
					return _sagoma("standee/sprout.webp", "", Color.WHITE, Color(0.2, 0.35, 0.15), 0.42)
				return _cubetto(colx))
			_metti(nodo4, _v3(c + Vector2(-r.size.x * 0.38 + (k % 5) * 0.32, r.size.y * 0.02 + (k / 5) * 0.32)))
	for chiave in _pedine.keys():
		if not viste.has(chiave):
			_pedine[chiave].queue_free()
			_pedine.erase(chiave)

func _pedina(chiave: String, crea: Callable) -> Node3D:
	if _pedine.has(chiave) and is_instance_valid(_pedine[chiave]):
		return _pedine[chiave]
	var n: Node3D = crea.call()
	n.set_meta("nuova", true)
	for ch in n.get_children():
		if ch.is_in_group("nomi_p3d"):
			ch.visible = _nomi_visibili
	_mondo.add_child(n)
	_pedine[chiave] = n
	return n

func _metti(n: Node3D, pos: Vector3) -> void:
	if n.get_meta("nuova", false):
		n.set_meta("nuova", false)
		n.position = pos
		n.set_meta("meta", pos)
		return
	if (n.get_meta("meta", Vector3.INF) as Vector3).distance_to(pos) < 0.01:
		return
	n.set_meta("meta", pos)
	var da := n.position
	var tw := n.create_tween()
	var salto := clampf(da.distance_to(pos) * 0.25, 0.3, 1.6)
	tw.tween_method(func(t: float):
		if is_instance_valid(n):
			n.position = da.lerp(pos, t) + Vector3(0, sin(t * PI) * salto, 0), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ------------------------------------------------------------------ pezzi

func _carica_mesh(nome: String) -> Mesh:
	if not _mesh.has(nome):
		var p := "res://assets/modelli/%s.obj" % nome
		_mesh[nome] = load(p) if ResourceLoader.exists(p) else null
	return _mesh[nome]

func _miniatura(m: Dictionary) -> Node3D:
	var radice := Node3D.new()
	var sez: Dictionary = Dati.SEZIONI.get(str(m.get("reparto", "")), {})
	var col: Color = sez.get("colore", Color.WHITE)
	var mesh := _carica_mesh(str(sez.get("modello", "capitano")))
	if mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mt := _mat()
		var tp := "res://assets/modelli/%s.png" % str(sez.get("modello", "capitano"))
		if ResourceLoader.exists(tp):
			mt.albedo_texture = load(tp)
		mt.roughness = 0.55
		mi.material_override = mt
		# i modelli sono esportati con l'asse Z verso l'alto: si raddrizzano
		var aabb := mesh.get_aabb()
		var k: float = ALTEZZA_MINI / maxf(aabb.size.z, 0.001)
		mi.rotation = Vector3(-PI / 2, PI, 0)
		mi.scale = Vector3(-k, k, k)
		mi.position.y = -aabb.position.z * k + 0.05
		radice.add_child(mi)
	else:
		var cap := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.22
		cm.height = ALTEZZA_MINI
		cap.mesh = cm
		cap.position.y = ALTEZZA_MINI / 2.0 + 0.07
		cap.material_override = _mat(col)
		radice.add_child(cap)
	# basetta nel colore del Reparto
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.36
	cil.bottom_radius = 0.38
	cil.height = 0.06
	base.mesh = cil
	var mb := _mat(col.darkened(0.15))
	mb.metallic = 0.4
	base.material_override = mb
	base.position.y = 0.035
	radice.add_child(base)
	# anello luminoso del Membro attivo
	var anello := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.4
	tor.outer_radius = 0.48
	anello.mesh = tor
	var ma := _mat(Tema.CIANO)
	ma.emission_enabled = true
	ma.emission = Tema.CIANO
	ma.emission_energy_multiplier = 2.0
	anello.material_override = ma
	anello.position.y = 0.04
	anello.name = "Anello"
	anello.visible = false
	radice.add_child(anello)
	var nome := Label3D.new()
	nome.text = str(m.get("carta", "")).get_slice(" ", 0).to_upper()
	nome.font = Tema.titolo
	nome.font_size = 40
	nome.pixel_size = 0.0005
	nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nome.fixed_size = true
	nome.no_depth_test = true
	nome.modulate = col.lightened(0.45)
	nome.outline_size = 10
	nome.outline_modulate = Color(0, 0, 0, 0.9)
	nome.position.y = ALTEZZA_MINI + 0.3
	nome.render_priority = 1
	nome.add_to_group("nomi_p3d")
	radice.add_child(nome)
	return radice

func _evidenzia_attivo(n: Node3D, si: bool) -> void:
	var a := n.get_node_or_null("Anello")
	if a:
		a.visible = si
		if si and not n.has_meta("tw_anello"):
			var tw := a.create_tween().set_loops()
			tw.tween_property(a, "scale", Vector3(1.15, 1, 1.15), 0.6).set_trans(Tween.TRANS_SINE)
			tw.tween_property(a, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_SINE)
			n.set_meta("tw_anello", tw)
		elif not si and n.has_meta("tw_anello"):
			(n.get_meta("tw_anello") as Tween).kill()
			n.remove_meta("tw_anello")
			a.scale = Vector3.ONE

## Segnalino della Minaccia: la carta in piedi su una basetta rossa, sempre rivolta verso la telecamera.
func _standee(m: Dictionary) -> Node3D:
	var radice := Node3D.new()
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.3
	cil.bottom_radius = 0.32
	cil.height = 0.06
	base.mesh = cil
	base.material_override = _mat(Color(0.38, 0.04, 0.07))
	base.position.y = 0.04
	radice.add_child(base)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.95, 1.33)
	q.mesh = qm
	var mq := _mat()
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mq.billboard_keep_scale = true
	mq.cull_mode = BaseMaterial3D.CULL_DISABLED
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material_override = mq
	q.position.y = 0.08 + 0.665
	q.name = "Carta"
	radice.add_child(q)
	var nome := Label3D.new()
	nome.font = Tema.titolo
	nome.font_size = 34
	nome.pixel_size = 0.0005
	nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nome.fixed_size = true
	nome.no_depth_test = true
	nome.modulate = Color(1.0, 0.55, 0.55)
	nome.outline_size = 10
	nome.outline_modulate = Color(0, 0, 0, 0.9)
	nome.position.y = 1.65
	nome.name = "Nome"
	nome.render_priority = 1
	nome.add_to_group("nomi_p3d")
	radice.add_child(nome)
	_aggiorna_standee(radice, m)
	return radice

## Standee del modulo (sagoma ritagliata) per nome inglese della Minaccia o del Lander, "" se non c'è.
const STANDEE := ["aerugon_saboteur", "apex_predator", "arrogator_behemoth", "arrogator_warswarm", "bombardment", "builder_s_biomebot",
	"carnivorous_thicket", "dragonfly", "drone", "dust_storm", "enraptured_visitor", "faustschlag", "flowerbug", "guardian_metahedron",
	"idemian_pilgrim", "kurma", "magnacereb", "maw", "ophthalmoid", "pelican", "scintillating_shardfly", "space_ranger", "sprout",
	"void_ranger", "waygate"]

static func file_standee(nome: String) -> String:
	var k := RegEx.create_from_string("[^a-z0-9]+").sub(nome.to_lower(), "", true)
	for f in STANDEE:
		if f.replace("_", "") == k:
			return "standee/%s.webp" % f
	# varianti ("Converted Arrogator Behemoth", "Idemian Pilgrim" infuriato…)
	for f in STANDEE:
		if f.length() > 5 and k.contains(f.replace("_", "")):
			return "standee/%s.webp" % f
	return ""

## Altezza dello standee in proporzione alla sagoma originale (le Minacce grandi restano grandi).
static func _altezza_standee(px: float) -> float:
	return clampf(px / 300.0, 0.55, 2.1)

func _aggiorna_standee(n: Node3D, m: Dictionary) -> void:
	n.set_meta("file", str(m.get("file", "")))
	var nome: Label3D = n.get_node("Nome")
	nome.text = "☠ " + str(m.get("nome", "")).to_upper()
	var q: MeshInstance3D = n.get_node("Carta")
	var mq: StandardMaterial3D = q.material_override
	var sagoma := file_standee(str(m.get("en", "")))
	if sagoma == "":
		sagoma = file_standee(str(Carte.per_file(str(m.get("file", ""))).get("nomi", [""])[0]))
	if sagoma != "":
		# sagoma ritagliata del modulo: trasparente, sulla basetta
		mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mq.alpha_scissor_threshold = 0.4
		Immagini.carica(sagoma, func(t):
			if is_instance_valid(q) and t:
				var s: Vector2 = t.get_size()
				var h := _altezza_standee(s.y)
				var qm := QuadMesh.new()
				qm.size = Vector2(h * s.x / s.y, h)
				q.mesh = qm
				q.position.y = 0.08 + h / 2.0
				nome.position.y = h + 0.35
				mq.albedo_texture = t)
		return
	Immagini.carica(str(m.get("file", "")), func(t):
		if is_instance_valid(q) and t:
			var s: Vector2 = t.get_size()
			var qm := QuadMesh.new()
			qm.size = Vector2(1.33 * s.x / s.y, 1.33)
			q.mesh = qm
			mq.albedo_texture = t)

func _lander() -> Node3D:
	var sagoma := file_standee(str(_nome_lander))
	if sagoma != "":
		return _sagoma(sagoma, "LANDER " + str(_nome_lander).to_upper(), Color(0.55, 0.85, 1.0), Color(0.12, 0.16, 0.2), 1.5)
	var radice := Node3D.new()
	var corpo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.radial_segments = 6
	cil.top_radius = 0.38
	cil.bottom_radius = 0.55
	cil.height = 0.5
	corpo.mesh = cil
	var mc := _mat(Color(0.72, 0.75, 0.8))
	mc.metallic = 0.6
	mc.roughness = 0.35
	corpo.material_override = mc
	corpo.position.y = 0.25
	radice.add_child(corpo)
	var cupola := MeshInstance3D.new()
	var sf := SphereMesh.new()
	sf.radius = 0.3
	sf.height = 0.42
	cupola.mesh = sf
	var mcu := _mat(Color(0.3, 0.75, 1.0))
	mcu.emission_enabled = true
	mcu.emission = Color(0.2, 0.6, 1.0)
	mcu.emission_energy_multiplier = 0.6
	cupola.material_override = mcu
	cupola.position.y = 0.55
	radice.add_child(cupola)
	for k in 3:
		var gamba := MeshInstance3D.new()
		var g := CylinderMesh.new()
		g.top_radius = 0.035
		g.bottom_radius = 0.05
		g.height = 0.45
		gamba.mesh = g
		gamba.material_override = mc
		var a := k * TAU / 3.0
		gamba.position = Vector3(cos(a) * 0.55, 0.18, sin(a) * 0.55)
		gamba.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
		radice.add_child(gamba)
	var l := Label3D.new()
	l.text = "LANDER"
	l.font = Tema.titolo
	l.font_size = 30
	l.pixel_size = 0.0005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.no_depth_test = true
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.position.y = 1.05
	l.render_priority = 1
	l.add_to_group("nomi_p3d")
	radice.add_child(l)
	return radice

var _nome_lander := ""

## Una sagoma ritagliata in piedi su una basetta, sempre rivolta verso la telecamera.
func _sagoma(file: String, testo: String, col_testo: Color, col_base: Color, largo: float) -> Node3D:
	var radice := Node3D.new()
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = minf(0.3, largo * 0.24)
	cil.bottom_radius = minf(0.32, largo * 0.26)
	cil.height = 0.07
	base.mesh = cil
	base.material_override = _mat(col_base)
	base.position.y = 0.035
	radice.add_child(base)
	var q := MeshInstance3D.new()
	var mq := _mat()
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mq.billboard_keep_scale = true
	mq.cull_mode = BaseMaterial3D.CULL_DISABLED
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mq.alpha_scissor_threshold = 0.4
	q.material_override = mq
	radice.add_child(q)
	var l: Label3D = null
	if testo != "":
		l = Label3D.new()
		l.text = testo
		l.font = Tema.titolo
		l.font_size = 28
		l.pixel_size = 0.0005
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.no_depth_test = true
		l.modulate = col_testo
		l.outline_size = 8
		l.outline_modulate = Color(0, 0, 0, 0.9)
		l.position.y = 1.0
		l.render_priority = 1
		l.add_to_group("nomi_p3d")
		radice.add_child(l)
	Immagini.carica(file, func(t):
		if is_instance_valid(q) and t:
			var s: Vector2 = t.get_size()
			var w := largo
			var h := w * s.y / s.x
			var qm := QuadMesh.new()
			qm.size = Vector2(w, h)
			q.mesh = qm
			q.position.y = 0.07 + h / 2.0
			if l:
				l.position.y = h + 0.3
			mq.albedo_texture = t)
	return radice

func _gettone(col: Color, testo: String, r: float) -> Node3D:
	var radice := Node3D.new()
	var g := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = r
	cil.bottom_radius = r
	cil.height = 0.12
	g.mesh = cil
	var m := _mat(col)
	m.metallic = 0.3
	g.material_override = m
	g.position.y = 0.06
	radice.add_child(g)
	var l := Label3D.new()
	l.text = "⚙ " + testo
	l.font = Tema.titolo
	l.font_size = 26
	l.pixel_size = 0.0005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.no_depth_test = true
	l.modulate = col.lightened(0.4)
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.position.y = 0.45
	l.render_priority = 1
	l.add_to_group("nomi_p3d")
	radice.add_child(l)
	return radice

func _cubetto(col: Color) -> Node3D:
	var radice := Node3D.new()
	var c := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.22, 0.22, 0.22)
	c.mesh = b
	c.material_override = _mat(col)
	c.position.y = 0.11
	radice.add_child(c)
	return radice

# ------------------------------------------------------------------ telecamera e mouse

func vista_iniziale(anima := false) -> void:
	_vai(Vector3(0, 0, D * 0.04), maxf(W, D * 2.0) * 0.98, 62.0, 0.0, anima)

func _ruota(gradi: float) -> void:
	_vai(_cam_t, _cam_d, _cam_p, _cam_y + gradi, true)

func _inquadra_attivo() -> void:
	if mis == null or mis.esp.vivi().is_empty():
		return
	var n := int(mis.esp.membro(int(mis.esp.s["attivo"]))["settore"])
	if _settori.has(n):
		_vai(_v3(_settori[n]["rett"].get_center()), 9.0, 52.0, _cam_y, true)

func inquadra_settore(n: int) -> void:
	if _settori.has(n):
		_vai(_v3(_settori[n]["rett"].get_center()), minf(_cam_d, 12.0), _cam_p, _cam_y, true)

func _vai(t: Vector3, d: float, p: float, y: float, anima: bool) -> void:
	if _tw_cam:
		_tw_cam.kill()
	if not anima:
		_cam_t = t
		_cam_d = d
		_cam_p = p
		_cam_y = y
		_aggiorna_camera()
		return
	var t0 := _cam_t
	var d0 := _cam_d
	var p0 := _cam_p
	var y0 := _cam_y
	_tw_cam = create_tween()
	_tw_cam.tween_method(func(k: float):
		_cam_t = t0.lerp(t, k)
		_cam_d = lerpf(d0, d, k)
		_cam_p = lerpf(p0, p, k)
		_cam_y = lerpf(y0, y, k)
		_aggiorna_camera(), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _aggiorna_camera() -> void:
	_cam_p = clampf(_cam_p, 15.0, 89.0)
	_cam_d = clampf(_cam_d, 2.5, 60.0)
	_cam_t.x = clampf(_cam_t.x, -W * 0.6, W * 0.6)
	_cam_t.z = clampf(_cam_t.z, -D * 0.6, D * 0.6)
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -deg_to_rad(_cam_p)).rotated(Vector3.UP, deg_to_rad(_cam_y))
	camera.position = _cam_t + dir * _cam_d
	camera.look_at(_cam_t, Vector3.UP)
	# da lontano i nomi sopra le pedine si nascondono (restano numeri e annotazioni dei settori)
	var vicini := _cam_d < 16.0
	if vicini != _nomi_visibili and is_inside_tree():
		_nomi_visibili = vicini
		get_tree().set_group("nomi_p3d", "visible", vicini)

func _punto_piano(pos: Vector2, quota := 0.0) -> Vector3:
	var from := camera.project_ray_origin(pos)
	var dir := camera.project_ray_normal(pos)
	if absf(dir.y) < 0.0001:
		return from
	return from + dir * ((quota - from.y) / dir.y)

## Settore sotto il punto dello schermo (-1 se nessuno).
func settore_in(pos: Vector2) -> int:
	var p := _punto_piano(pos)
	var q := Vector2(p.x, p.z)
	var migliore := -1
	var area := INF
	for n in _settori:
		var r: Rect2 = _settori[n]["rett"]
		if r.has_point(q) and r.get_area() < area:
			migliore = int(n)
			area = r.get_area()
	return migliore

func _hover(n: int) -> void:
	if n != _sopra:
		_sopra = n
		aggiorna()
	_vpc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if n >= 0 else Control.CURSOR_ARROW

func _input_vista(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb: InputEventMouseButton = e
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom(mb.position, 0.88)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom(mb.position, 1.0 / 0.88)
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_premuto = true
					_premuto_pos = mb.position
					_ultimo = mb.position
				else:
					if not _pan and mb.position.distance_to(_premuto_pos) < SOGLIA:
						var n := settore_in(mb.position)
						if n >= 0:
							cliccato.emit(n)
					_premuto = false
					_pan = false
			MOUSE_BUTTON_RIGHT:
				_orbita = mb.pressed
				_ultimo = mb.position
			MOUSE_BUTTON_MIDDLE:
				_pan = mb.pressed
				_ultimo = mb.position
		_vpc.accept_event()
	elif e is InputEventMouseMotion:
		var mm: InputEventMouseMotion = e
		var delta := mm.position - _ultimo
		_ultimo = mm.position
		if _orbita:
			if _tw_cam:
				_tw_cam.kill()
			_cam_y -= delta.x * 0.3
			_cam_p += delta.y * 0.25
			_aggiorna_camera()
		elif _premuto and not _pan and mm.position.distance_to(_premuto_pos) >= SOGLIA:
			_pan = true
		if _pan and (mm.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE)):
			if _tw_cam:
				_tw_cam.kill()
			var a := _punto_piano(mm.position - delta)
			var b := _punto_piano(mm.position)
			_cam_t += a - b
			_aggiorna_camera()
		elif not _orbita:
			_hover(settore_in(mm.position))
	elif e is InputEventMagnifyGesture:
		_cam_d /= (e as InputEventMagnifyGesture).factor
		_aggiorna_camera()
	elif e is InputEventPanGesture:
		var pg: InputEventPanGesture = e
		_cam_t += Vector3(pg.delta.x, 0, pg.delta.y).rotated(Vector3.UP, deg_to_rad(_cam_y)) * _cam_d * 0.02
		_aggiorna_camera()

func _zoom(pos: Vector2, k: float) -> void:
	if _tw_cam:
		_tw_cam.kill()
	var prima := _punto_piano(pos)
	_cam_d *= k
	_aggiorna_camera()
	var dopo := _punto_piano(pos)
	_cam_t += Vector3(prima.x - dopo.x, 0, prima.z - dopo.z)
	_aggiorna_camera()

## Il tavolo 3D: costruisce tutti i componenti nella disposizione del modulo TTS,
## gestisce telecamera, selezione, trascinamento, mazzi, sacchetti e dadi,
## e salva/ripristina lo stato completo nella campagna.
class_name Tavolo
extends Node3D

signal sopra(p: Pezzo)                       # pezzo sotto il mouse (o null)
signal menu(p: Pezzo, pos: Vector2)          # clic destro su un pezzo
signal apri_contenuto(p: Pezzo)              # sfoglia un mazzo o un sacchetto
signal messaggio(t: String)
signal dado_tirato(p: Pezzo, faccia: int)
signal libro(p: Pezzo)

const ALTEZZA_TTS := 1.45   # quota del piano del tavolo nel modulo TTS
const SOGLIA_TRASCINA := 6.0

const VISTE := {
	"pianeta": {"t": Vector3(0, 0, -4.5), "d": 24.0, "p": 58.0, "y": 0.0, "nome": "Pianeta"},
	"nave": {"t": Vector3(-2, 0, -36), "d": 46.0, "p": 60.0, "y": 0.0, "nome": "Nave"},
	"equipaggio": {"t": Vector3(0, 0, 14), "d": 42.0, "p": 55.0, "y": 0.0, "nome": "Equipaggio"},
	"mazzi": {"t": Vector3(36, 0, 0), "d": 26.0, "p": 62.0, "y": 0.0, "nome": "Mazzi"},
	"scoperte": {"t": Vector3(-22, 0, -8), "d": 30.0, "p": 60.0, "y": 0.0, "nome": "Scoperte e mazzi"},
	"tutto": {"t": Vector3(-2, 0, -13), "d": 105.0, "p": 68.0, "y": 0.0, "nome": "Tutto il tavolo"},
}

var defs := {}              # id -> definizione (statica dal catalogo)
var tipi := {}              # id -> tipo di pezzo
var pezzi := {}             # id -> Pezzo sul tavolo
var dinamici := {}          # id -> definizione creata in partita (mazzi nuovi, copie dai sacchetti infiniti)
var _cont_dinamici := 0

var camera: Camera3D
var _cam_t := Vector3(0, 0, -4.5)
var _cam_d := 24.0
var _cam_p := 58.0
var _cam_y := 0.0
var _tween_cam: Tween

var _sopra: Pezzo
var _selezionato: Pezzo
var _trascina: Pezzo
var _premuto_su: Pezzo
var _premuto_pos := Vector2.ZERO
var _premuto_bottone := 0
var _offset := Vector3.ZERO
var _orbita := false
var _pan := false
var _ultimo_mouse := Vector2.ZERO
var input_attivo := true

func _ready() -> void:
	_ambiente()
	camera = Camera3D.new()
	camera.fov = 45
	camera.near = 0.1
	camera.far = 600
	add_child(camera)
	_aggiorna_camera()
	_registra()

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
	env.ambient_light_color = Color(0.55, 0.62, 0.75)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	we.environment = env
	add_child(we)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-62, 25, 0)
	sole.light_energy = 1.05
	sole.light_color = Color(0.95, 0.97, 1.0)
	sole.shadow_enabled = true
	sole.directional_shadow_max_distance = 140
	add_child(sole)
	var riemp := DirectionalLight3D.new()
	riemp.rotation_degrees = Vector3(-35, 200, 0)
	riemp.light_energy = 0.25
	riemp.light_color = Color(0.5, 0.75, 1.0)
	add_child(riemp)
	# piano del tavolo: metallo scuro con griglia luminosa
	var piano := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(124, 86)
	piano.mesh = pm
	piano.position = Vector3(-2, -0.001, -13)
	var sh := ShaderMaterial.new()
	sh.shader = Shader.new()
	sh.shader.code = """shader_type spatial;
render_mode specular_schlick_ggx;
void fragment(){
	vec2 p = UV * vec2(124.0, 86.0);
	vec2 g = abs(fract(p / 2.0) - 0.5);
	float linea = 1.0 - smoothstep(0.0, 0.035, min(g.x, g.y));
	vec2 g2 = abs(fract(p / 10.0) - 0.5);
	float linea2 = 1.0 - smoothstep(0.0, 0.012, min(g2.x, g2.y));
	float bordo = smoothstep(0.0, 0.02, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	vec3 base = mix(vec3(0.018, 0.03, 0.055), vec3(0.03, 0.05, 0.09), UV.y);
	ALBEDO = base + vec3(0.05, 0.16, 0.26) * (linea * 0.25 + linea2 * 0.5);
	ALBEDO = mix(vec3(0.15, 0.55, 0.8), ALBEDO, bordo);
	ROUGHNESS = 0.6;
	METALLIC = 0.35;
	EMISSION = vec3(0.05, 0.2, 0.35) * linea2 * 0.6 + vec3(0.1, 0.4, 0.7) * (1.0 - bordo);
}"""
	piano.material_override = sh
	add_child(piano)
	var corpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(124, 0.2, 86)
	cs.shape = bs
	cs.position = Vector3(-2, -0.1, -13)
	corpo.add_child(cs)
	corpo.set_meta("piano", true)
	add_child(corpo)

# ------------------------------------------------------------------ registro dei pezzi

static func tipo_di(d: Dictionary) -> String:
	var t: String = d.get("tipo", "")
	if d.has("fronte") and t in ["Card", "CardCustom", ""]:
		return "carta"
	match t:
		"Card", "CardCustom": return "carta"
		"Deck", "DeckCustom": return "mazzo"
		"Custom_Token", "Custom_Tile": return "tessera"
		"Figurine_Custom": return "standee"
		"Custom_Dice", "Die_10": return "dado"
		"Bag", "Infinite_Bag": return "sacchetto"
		"Custom_Model_Bag": return "modello"
		"Custom_Model": return "modello"
		"Custom_Assetbundle":
			var b := str(d.get("bundle", ""))
			if b.contains("1845916597"): return "miniatura"
			if b.contains("pottray") or b.contains("pot_tray") or b.begins_with("chrymetts3droom"): return "vassoio"
			return "ciotola"
		"Bowl": return "ciotola"
		"3DText": return "testo"
		"Custom_PDF": return "libro"
		"BlockSquare": return "cubetto"
	return ""

func _registra() -> void:
	var visti := {}
	for o in Dati.componenti.get("oggetti", []):
		_registra_def(o, visti)

func _registra_def(d: Dictionary, visti: Dictionary) -> void:
	var g := str(d.get("guid", ""))
	if g == "":
		g = "x"
	var id := g
	var n := 1
	while visti.has(id):
		n += 1
		id = "%s_%d" % [g, n]
	visti[id] = true
	d["_id"] = id
	defs[id] = d
	tipi[id] = tipo_di(d)
	for c in d.get("carte", []):
		_registra_def(c, visti)
		tipi[c["_id"]] = "carta"
	for x in d.get("contenuto", []):
		_registra_def(x, visti)

func def_per_id(id: String) -> Dictionary:
	if defs.has(id):
		return defs[id]
	if dinamici.has(id):
		return dinamici[id]
	if id.contains("#"):
		var base := id.get_slice("#", 0)
		if defs.has(base):
			var c: Dictionary = defs[base].duplicate(true)
			c["_id"] = id
			dinamici[id] = c
			return c
	return {}

func tipo_per_id(id: String) -> String:
	if tipi.has(id):
		return tipi[id]
	return tipo_di(def_per_id(id))

# ------------------------------------------------------------------ allestimento

## Disposizione iniziale: tutti gli oggetti del modulo TTS al loro posto.
func allestisci() -> void:
	for o in Dati.componenti.get("oggetti", []):
		var id: String = o["_id"]
		var ti := tipo_per_id(id)
		if ti == "" or float(o["t"][1]) < 0.0 or o.get("nota_tts", false):
			continue  # oggetti nascosti sotto il tavolo nel modulo o di servizio
		var p := _crea(id, ti)
		if p == null:
			continue
		var t: Array = o["t"]
		p.position = Vector3(float(t[0]), max(0.0, float(t[1]) - ALTEZZA_TTS), -float(t[2]))
		p.rotation.y = rot_tts(float(t[4]))
		var rz := absf(fposmod(float(t[5]), 360.0) - 180.0)
		p.faccia_su = rz > 90.0  # rotZ ≈ 180 = coperto
		if ti == "mazzo":
			p.contenuto = (o.get("carte", []) as Array).duplicate()
		elif ti in ["sacchetto", "modello"] and o.has("contenuto"):
			p.contenuto = (o.get("contenuto", []) as Array).duplicate()
			p.infinito = o.get("tipo", "") == "Infinite_Bag"
		p.bloccato = o.get("bloccato", false) and ti in ["vassoio", "tessera", "testo", "libro", "modello", "ciotola"]
		p.costruisci()
	_assesta()

## Rotazione TTS (mano sinistra, 180° = dritto per il giocatore) -> Godot.
static func rot_tts(gradi: float) -> float:
	return wrapf(PI - deg_to_rad(gradi), -PI, PI)

func _crea(id: String, ti: String) -> Pezzo:
	var d := def_per_id(id)
	if d.is_empty() or ti == "":
		return null
	var p := Pezzo.new(id, d, ti)
	p.tavolo = self
	pezzi[id] = p
	add_child(p)
	return p

## Appoggia i pezzi piatti uno sull'altro senza compenetrazioni (dal basso verso l'alto).
func _assesta() -> void:
	var ord := pezzi.values()
	ord.sort_custom(func(a, b): return a.position.y < b.position.y)
	var messi: Array = []
	for p in ord:
		var base := 0.0
		for q in messi:
			if _sovrapposti(p, q):
				base = max(base, _cima(q))
		p.position.y = base + _meta_altezza(p)
		messi.append(p)

func _meta_altezza(p: Pezzo) -> float:
	return p.dim.y * 0.5 if p.tipo in ["carta", "mazzo", "tessera", "libro"] else 0.0

func _cima(q: Pezzo) -> float:
	if q.tipo in ["carta", "mazzo", "tessera", "libro"]:
		return q.position.y + q.dim.y * 0.5
	if q.tipo == "vassoio":
		return q.position.y + 0.07
	return q.position.y + q.dim.y

func _sovrapposti(p: Pezzo, q: Pezzo) -> bool:
	if q.tipo in ["standee", "dado", "miniatura", "sacchetto", "ciotola", "testo", "cubetto"]:
		return false
	var e := _estensione(q)
	var d := p.position - q.position
	var loc := Vector2(d.x, d.z).rotated(q.rotation.y)
	return absf(loc.x) < e.x * 0.5 and absf(loc.y) < e.y * 0.5

func _estensione(q: Pezzo) -> Vector2:
	return Vector2(q.dim.x, q.dim.z)

## Ripristina lo stato salvato; se non c'è, allestisce da zero.
func ripristina(stato: Dictionary) -> void:
	for id in pezzi.keys():
		pezzi[id].queue_free()
	pezzi.clear()
	var lista: Array = stato.get("pezzi", [])
	if lista.is_empty():
		allestisci()
		return
	for k in stato.get("dinamici", {}):
		dinamici[k] = stato["dinamici"][k]
	_cont_dinamici = int(stato.get("n", 0))
	for s in lista:
		var id := str(s.get("id", ""))
		var ti := tipo_per_id(id)
		var p := _crea(id, ti)
		if p == null:
			continue
		var pp: Array = s.get("p", [0, 0, 0])
		p.position = Vector3(pp[0], pp[1], pp[2])
		p.rotation.y = deg_to_rad(float(s.get("r", 0)))
		p.faccia_su = int(s.get("f", 1)) == 1
		p.stato = int(s.get("s", 0))
		p.bloccato = int(s.get("b", 0)) == 1
		p.valore_dado = int(s.get("v", 0))
		if s.has("k"):
			p.def["t"] = [0, 0, 0, 0, 0, 0, float(s["k"]), 1, float(s["k"])]
		var d := p.def
		if ti in ["sacchetto", "modello"] and d.get("tipo", "") == "Infinite_Bag":
			p.infinito = true
			p.contenuto = (d.get("contenuto", []) as Array).duplicate()
		elif s.has("c"):
			p.contenuto = []
			for cid in s["c"]:
				var cd := def_per_id(str(cid))
				if not cd.is_empty():
					p.contenuto.append(cd)
		p.costruisci()
		if ti == "dado":
			p.imposta_faccia_dado(p.valore_dado)
	var cam: Dictionary = stato.get("cam", {})
	if cam.has("t"):
		_cam_t = Vector3(cam["t"][0], cam["t"][1], cam["t"][2])
		_cam_d = float(cam.get("d", _cam_d))
		_cam_p = float(cam.get("p", _cam_p))
		_cam_y = float(cam.get("y", _cam_y))
		_aggiorna_camera()

func serializza() -> Dictionary:
	var lista := []
	var din := {}
	for id in pezzi:
		var p: Pezzo = pezzi[id]
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		lista.append(p.serializza())
	for k in dinamici:
		var d: Dictionary = dinamici[k]
		if not k.contains("#"):
			din[k] = d
	return {"pezzi": lista, "dinamici": din, "n": _cont_dinamici,
		"cam": {"t": [_cam_t.x, _cam_t.y, _cam_t.z], "d": _cam_d, "p": _cam_p, "y": _cam_y}}

# ------------------------------------------------------------------ telecamera

func _aggiorna_camera() -> void:
	_cam_p = clampf(_cam_p, 18.0, 89.0)
	_cam_d = clampf(_cam_d, 3.0, 140.0)
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -deg_to_rad(_cam_p)).rotated(Vector3.UP, deg_to_rad(_cam_y))
	camera.position = _cam_t + dir * _cam_d
	camera.look_at(_cam_t, Vector3.UP)

func vista(nome: String) -> void:
	if not VISTE.has(nome):
		return
	var v: Dictionary = VISTE[nome]
	vai_a(v["t"], v["d"], v["p"], v["y"])

func vai_a(t: Vector3, d: float, p := -1.0, y := INF) -> void:
	if _tween_cam:
		_tween_cam.kill()
	_tween_cam = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween_cam.tween_method(func(x): _cam_t = x; _aggiorna_camera(), _cam_t, t, 0.6)
	_tween_cam.tween_method(func(x): _cam_d = x; _aggiorna_camera(), _cam_d, d, 0.6)
	if p > 0:
		_tween_cam.tween_method(func(x): _cam_p = x; _aggiorna_camera(), _cam_p, p, 0.6)
	if y != INF:
		var dy := wrapf(y - _cam_y, -180.0, 180.0)
		_tween_cam.tween_method(func(x): _cam_y = x; _aggiorna_camera(), _cam_y, _cam_y + dy, 0.6)

func inquadra(p: Pezzo) -> void:
	vai_a(Vector3(p.position.x, 0, p.position.z), clampf(max(p.dim.x, p.dim.z) * 2.6, 6.0, 40.0))

# ------------------------------------------------------------------ selezione

func _raggio(pos: Vector2, escludi: Array = []) -> Dictionary:
	var from := camera.project_ray_origin(pos)
	var to := from + camera.project_ray_normal(pos) * 500.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = escludi
	return get_world_3d().direct_space_state.intersect_ray(q)

func pezzo_in(pos: Vector2, escludi: Array = []) -> Pezzo:
	var r := _raggio(pos, escludi)
	if r.is_empty():
		return null
	var c = r["collider"]
	if c and c.has_meta("pezzo"):
		return c.get_meta("pezzo")
	return null

func _punto_piano(pos: Vector2, quota := 0.0) -> Vector3:
	var from := camera.project_ray_origin(pos)
	var dir := camera.project_ray_normal(pos)
	if absf(dir.y) < 0.0001:
		return from
	var k := (quota - from.y) / dir.y
	return from + dir * k

func selezionato() -> Pezzo:
	return _selezionato if is_instance_valid(_selezionato) else null

func seleziona(p: Pezzo) -> void:
	if is_instance_valid(_selezionato):
		_selezionato.evidenzia(false)
	_selezionato = p
	if p:
		p.evidenzia(true, Tema.AMBRA)

func _unhandled_input(e: InputEvent) -> void:
	if not input_attivo or camera == null:
		return
	if e is InputEventMouseButton:
		_tasto_mouse(e)
	elif e is InputEventMouseMotion:
		_movimento(e)
	elif e is InputEventMagnifyGesture:
		_cam_d /= e.factor
		_aggiorna_camera()
	elif e is InputEventPanGesture:
		var k := _cam_d * 0.02
		_cam_t += Vector3(e.delta.x, 0, e.delta.y).rotated(Vector3.UP, deg_to_rad(_cam_y)) * k
		_aggiorna_camera()
	elif e is InputEventKey and e.pressed and not e.echo:
		_tasto(e)

func _tasto_mouse(e: InputEventMouseButton) -> void:
	if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
		_zoom_verso(e.position, 0.88)
	elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
		_zoom_verso(e.position, 1.0 / 0.88)
	elif e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_premuto_su = pezzo_in(e.position)
			_premuto_pos = e.position
			_premuto_bottone = MOUSE_BUTTON_LEFT
			_ultimo_mouse = e.position
			if e.double_click and _premuto_su:
				_doppio_clic(_premuto_su)
				_premuto_su = null
		else:
			if _trascina:
				_rilascia(e.position)
			elif _pan:
				_pan = false
			elif _premuto_su and e.position.distance_to(_premuto_pos) < SOGLIA_TRASCINA:
				seleziona(_premuto_su)
			elif _premuto_su == null and e.position.distance_to(_premuto_pos) < SOGLIA_TRASCINA:
				seleziona(null)
			_premuto_su = null
	elif e.button_index == MOUSE_BUTTON_RIGHT:
		if e.pressed:
			_premuto_pos = e.position
			_ultimo_mouse = e.position
			_orbita = true
		else:
			_orbita = false
			if e.position.distance_to(_premuto_pos) < SOGLIA_TRASCINA:
				var p := pezzo_in(e.position)
				if p:
					seleziona(p)
					menu.emit(p, e.position)
	elif e.button_index == MOUSE_BUTTON_MIDDLE:
		_pan = e.pressed
		_ultimo_mouse = e.position

func _zoom_verso(pos: Vector2, k: float) -> void:
	var prima := _punto_piano(pos)
	_cam_d *= k
	_aggiorna_camera()
	var dopo := _punto_piano(pos)
	_cam_t += Vector3(prima.x - dopo.x, 0, prima.z - dopo.z)
	_aggiorna_camera()

func _movimento(e: InputEventMouseMotion) -> void:
	var delta := e.position - _ultimo_mouse
	_ultimo_mouse = e.position
	if _orbita:
		_cam_y -= delta.x * 0.3
		_cam_p += delta.y * 0.25
		_aggiorna_camera()
		return
	if _trascina:
		_trascina_a(e.position)
		return
	if _premuto_bottone == MOUSE_BUTTON_LEFT and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) and e.position.distance_to(_premuto_pos) >= SOGLIA_TRASCINA:
		if _premuto_su and not _premuto_su.bloccato and not _pan:
			var p := _premuto_su
			if e.shift_pressed and p.tipo == "mazzo" and p.contenuto.size() > 1:
				p = _estrai_dal_mazzo(p)
			elif p.tipo in ["sacchetto", "modello"] and not p.contenuto.is_empty() and not e.shift_pressed:
				p = _estrai_dal_sacchetto(p)
			if p:
				_inizia_trascina(p, e.position)
			_premuto_su = null
			return
		if _premuto_su == null or (_premuto_su and _premuto_su.bloccato):
			_pan = true
			_premuto_su = null
	if _pan:
		var a := _punto_piano(e.position - delta)
		var b := _punto_piano(e.position)
		_cam_t += a - b
		_aggiorna_camera()
		return
	var p2 := pezzo_in(e.position)
	if p2 != _sopra:
		if is_instance_valid(_sopra) and _sopra != _selezionato:
			_sopra.evidenzia(false)
		_sopra = p2
		if p2 and p2 != _selezionato:
			p2.evidenzia(true)
		sopra.emit(p2)

func _inizia_trascina(p: Pezzo, pos: Vector2) -> void:
	_trascina = p
	seleziona(p)
	var punto := _punto_piano(pos, p.position.y)
	_offset = p.position - punto
	_offset.y = 0
	_trascina_a(pos)

func _trascina_a(pos: Vector2) -> void:
	var p := _trascina
	var pt := _punto_piano(pos, 0.0) + _offset
	p.position = Vector3(pt.x, 1.2 + _meta_altezza(p), pt.z)

func _rilascia(pos: Vector2) -> void:
	var p := _trascina
	_trascina = null
	var esc: Array = [p._corpo.get_rid()]
	var sotto := _pezzo_sotto(p, esc)
	if sotto and sotto != p:
		if _unisci(p, sotto):
			Campagna.modificata()
			return
	_appoggia(p)
	Campagna.modificata()

## Il pezzo su cui cadrebbe p (raggio verticale dal suo centro).
func _pezzo_sotto(p: Pezzo, esc: Array) -> Pezzo:
	var from := Vector3(p.position.x, 30, p.position.z)
	var q := PhysicsRayQueryParameters3D.create(from, Vector3(p.position.x, -1, p.position.z))
	q.exclude = esc
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or not r["collider"].has_meta("pezzo"):
		return null
	return r["collider"].get_meta("pezzo")

## Appoggia un pezzo sopra quello che ha sotto.
func _appoggia(p: Pezzo) -> void:
	var base := 0.0
	for id in pezzi:
		var q: Pezzo = pezzi[id]
		if q == p or not is_instance_valid(q):
			continue
		if _sovrapposti(p, q):
			base = max(base, _cima(q))
	var y := base + _meta_altezza(p)
	var tw := create_tween()
	tw.tween_property(p, "position:y", y, 0.12)

## Carta su carta = nuovo mazzo; carta/mazzo su mazzo = in cima; qualunque cosa su un sacchetto = dentro.
func _unisci(p: Pezzo, su: Pezzo) -> bool:
	var vicino: bool = Vector2(p.position.x - su.position.x, p.position.z - su.position.z).length() < min(su.dim.x, su.dim.z) * 0.45
	if su.tipo in ["sacchetto"] or (su.tipo == "modello" and su.def.get("tipo", "") == "Custom_Model_Bag"):
		if su.infinito:
			_rimuovi(p)
			messaggio.emit("Rimesso nella riserva: %s" % su.nome_visibile())
			return true
		su.contenuto.push_front(_def_da_pezzo(p))
		_rimuovi(p)
		messaggio.emit("Messo in: %s" % su.nome_visibile())
		return true
	if not vicino:
		return false
	if p.tipo == "carta" and su.tipo == "carta":
		var m := _nuovo_mazzo(su.position, su.rotation.y, [p.def, su.def], su.faccia_su)
		_rimuovi(p)
		_rimuovi(su)
		seleziona(m)
		return true
	if p.tipo == "carta" and su.tipo == "mazzo":
		su.aggiungi_in_cima(p.def)
		_rimuovi(p)
		return true
	if p.tipo == "mazzo" and su.tipo == "mazzo":
		var c := p.contenuto.duplicate()
		c.reverse()
		for x in c:
			su.contenuto.push_front(x)
		su._ricostruisci_mazzo()
		_rimuovi(p)
		return true
	if p.tipo == "mazzo" and su.tipo == "carta":
		p.contenuto.push_back(su.def)
		p.position = Vector3(su.position.x, p.position.y, su.position.z)
		p._ricostruisci_mazzo()
		_rimuovi(su)
		_appoggia(p)
		return true
	return false

func _def_da_pezzo(p: Pezzo) -> Dictionary:
	if p.tipo == "mazzo":
		# un mazzo messo in un sacchetto conserva le sue carte
		var d: Dictionary = p.def.duplicate()
		d["carte"] = p.contenuto.duplicate()
		var nid := _nuovo_id("mazzo")
		d["_id"] = nid
		d.erase("contenuto")
		var salv := d.duplicate()
		salv["carte"] = p.contenuto.map(func(x): return {"_rif": x.get("_id", "")})
		dinamici[nid] = d
		return d
	return p.def

func _nuovo_id(pref: String) -> String:
	_cont_dinamici += 1
	return "%s_%d" % [pref, _cont_dinamici]

func _nuovo_mazzo(pos: Vector3, rot_y: float, carte: Array, coperto: bool) -> Pezzo:
	var id := _nuovo_id("mazzo")
	var d := {"tipo": "Deck", "nome": "Mazzo", "guid": id, "_id": id, "t": [0, 0, 0, 0, 0, 0, _scala_carta(carte[0]), 1, _scala_carta(carte[0])]}
	dinamici[id] = d
	var m := _crea(id, "mazzo")
	m.contenuto = carte.duplicate()
	m.faccia_su = not coperto
	m.position = pos
	m.rotation.y = rot_y
	m.costruisci()
	_appoggia(m)
	return m

## Scala di una carta: quella del mazzo da cui viene (le carte dentro i mazzi non hanno posizione propria).
func _scala_carta(c: Dictionary) -> float:
	if c.has("_scala"):
		return float(c["_scala"])
	var t: Array = c.get("t", [])
	return float(t[6]) if t.size() > 6 else 1.0

func _rimuovi(p: Pezzo) -> void:
	pezzi.erase(p.id)
	if _selezionato == p:
		_selezionato = null
	if _sopra == p:
		_sopra = null
	p.queue_free()

## Toglie la carta in cima al mazzo e la mette sul tavolo come pezzo separato.
func _estrai_dal_mazzo(m: Pezzo, scoperta := -1) -> Pezzo:
	var c := m.pesca()
	if c.is_empty():
		return null
	c["_scala"] = m.scala
	var p := _crea(str(c["_id"]), "carta")
	if p == null:
		return null
	p.faccia_su = m.faccia_su if scoperta < 0 else scoperta == 1
	p.scala = m.scala
	p.def["t"] = [0, 0, 0, 0, 0, 0, m.scala, 1, m.scala]
	p.costruisci()
	p.position = m.position + Vector3(0, m.dim.y + 0.05, 0)
	p.rotation.y = m.rotation.y
	if m.contenuto.size() == 1:
		# resta una carta sola: il mazzo diventa una carta
		var ultima: Dictionary = m.contenuto[0]
		ultima["_scala"] = m.scala
		var q := _crea(str(ultima["_id"]), "carta")
		if q:
			q.def["t"] = [0, 0, 0, 0, 0, 0, m.scala, 1, m.scala]
			q.faccia_su = m.faccia_su
			q.costruisci()
			q.position = m.position
			q.rotation.y = m.rotation.y
			_appoggia(q)
		_rimuovi(m)
	elif m.contenuto.is_empty():
		_rimuovi(m)
	return p

func _estrai_dal_sacchetto(s: Pezzo, indice := 0) -> Pezzo:
	if s.contenuto.is_empty():
		return null
	var d: Dictionary
	var id: String
	if s.infinito:
		d = s.contenuto[0]
		_cont_dinamici += 1
		id = "%s#%d" % [d["_id"], _cont_dinamici]
		def_per_id(id)
	else:
		d = s.contenuto.pop_at(indice)
		id = str(d.get("_id", ""))
		if not defs.has(id) and not dinamici.has(id):
			dinamici[id] = d
	var ti := tipo_per_id(id)
	var p := _crea(id, ti)
	if p == null:
		return null
	if ti == "mazzo":
		p.contenuto = (def_per_id(id).get("carte", []) as Array).duplicate()
		p.faccia_su = false
	p.costruisci()
	p.position = s.position + Vector3(0, s.dim.y + 0.3, 0)
	return p

## Prende un elemento preciso da un mazzo o sacchetto (finestra "sfoglia").
func prendi_da(cont: Pezzo, indice: int, vicino := true) -> Pezzo:
	var p: Pezzo
	if cont.tipo == "mazzo":
		var c: Dictionary = cont.contenuto[indice]
		cont.contenuto.remove_at(indice)
		cont.contenuto.push_front(c)
		p = _estrai_dal_mazzo(cont, 1)
	else:
		p = _estrai_dal_sacchetto(cont, indice)
	if p and vicino:
		p.position = cont.position + Vector3(cont.dim.x + 0.6, 0, 0).rotated(Vector3.UP, cont.rotation.y)
		_appoggia(p)
		seleziona(p)
	Campagna.modificata()
	return p

# ------------------------------------------------------------------ azioni sul selezionato

func _doppio_clic(p: Pezzo) -> void:
	match p.tipo:
		"carta", "tessera":
			if p.numero_stati() > 1:
				p.cambia_stato()
			else:
				p.gira()
		"mazzo":
			pesca_da(p, true)
		"dado":
			tira(p)
		"sacchetto", "modello":
			apri_contenuto.emit(p)
		"libro":
			libro.emit(p)
		_:
			inquadra(p)
	Campagna.modificata()

func _tasto(e: InputEventKey) -> void:
	var p := selezionato()
	if p == null and is_instance_valid(_sopra):
		p = _sopra
	match e.keycode:
		KEY_1: vista("pianeta")
		KEY_2: vista("nave")
		KEY_3: vista("equipaggio")
		KEY_4: vista("mazzi")
		KEY_5: vista("scoperte")
		KEY_0: vista("tutto")
	if p == null:
		return
	match e.keycode:
		KEY_F:
			p.gira()
		KEY_Q:
			p.ruota(15 if e.shift_pressed else 90)
		KEY_E:
			p.ruota(-15 if e.shift_pressed else -90)
		KEY_R:
			if p.tipo == "dado":
				tira(p)
			elif p.tipo == "mazzo":
				p.mescola()
				messaggio.emit("Mazzo mescolato")
		KEY_T:
			p.cambia_stato()
		KEY_D:
			if p.tipo == "mazzo":
				pesca_da(p, true)
		KEY_L:
			p.bloccato = not p.bloccato
			messaggio.emit("Bloccato" if p.bloccato else "Sbloccato")
		KEY_Z:
			inquadra(p)
		_:
			return
	Campagna.modificata()
	get_viewport().set_input_as_handled()

## Pesca la prima carta e la mette accanto al mazzo.
func pesca_da(m: Pezzo, scoperta := true) -> Pezzo:
	var p := _estrai_dal_mazzo(m, 1 if scoperta else 0)
	if p == null:
		return null
	var lato := Vector3(m.dim.x + 0.5, 0, 0).rotated(Vector3.UP, m.rotation.y)
	p.position = m.position + lato
	_appoggia(p)
	seleziona(p)
	Campagna.modificata()
	return p

func tira(p: Pezzo) -> void:
	var f := p.tira()
	dado_tirato.emit(p, f)
	Campagna.modificata()

## Raccoglie le carte sciolte dello stesso tipo sotto il mazzo (comando "Raccogli").
func raggruppa_su(m: Pezzo) -> void:
	pass

# ------------------------------------------------------------------ carte nominate dal Logbook

## Trova la carta con quel nome (P107, M02…) sul tavolo o dentro mazzi/sacchetti e la porta
## davanti al Planetopedia, scoperta.
func porta_carta(nome: String) -> bool:
	nome = nome.to_upper()
	for id in pezzi:
		var p: Pezzo = pezzi[id]
		if p.tipo == "carta" and str(p.def.get("nome", "")).to_upper() == nome:
			p.faccia_su = true
			p._aggiorna_lato()
			_metti_in_zona(p)
			return true
	for id in pezzi.keys():
		var c: Pezzo = pezzi[id]
		if c.tipo == "mazzo" or (c.tipo in ["sacchetto", "modello"] and not c.infinito):
			for i in c.contenuto.size():
				var d: Dictionary = c.contenuto[i]
				var trovato := str(d.get("nome", "")).to_upper() == nome
				if not trovato and d.has("carte"):
					continue
				if trovato:
					var p := prendi_da(c, i, false)
					if p:
						p.faccia_su = true
						p._aggiorna_lato(false)
						_metti_in_zona(p)
						return true
	messaggio.emit("Carta %s non trovata sul tavolo" % nome)
	return false

var _zona_n := 0
func _metti_in_zona(p: Pezzo) -> void:
	_zona_n = (_zona_n + 1) % 8
	p.position = Vector3(-9.0 + _zona_n * 2.6, 0, -0.9)
	p.rotation.y = 0.0
	_appoggia(p)
	seleziona(p)
	vai_a(Vector3(0, 0, -2), 22.0, 58.0)
	messaggio.emit("Carta %s sul tavolo" % str(p.def.get("nome", "")))
	Campagna.modificata()

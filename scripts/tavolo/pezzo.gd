## Un componente fisico sul tavolo 3D: carta, mazzo, tessera, segnalino, standee, dado,
## sacchetto, vassoio del Ship Book, miniatura, scatola, libro. Le misure seguono il modulo TTS
## (1 unità TTS = 1 metro in Godot; l'asse z è ribaltato perché Godot ha la mano destra).
class_name Pezzo
extends Node3D

const CARTA_L := 2.2       # larghezza di una carta TTS a scala 1
const CARTA_A := 3.06      # altezza
const SPESSORE_CARTA := 0.006
const LATO_GETTONE := 4.6  # lato lungo di un Custom_Token TTS a scala 1
const LATO_TESSERA := 2.0  # lato corto di un Custom_Tile TTS a scala 1

var id := ""
var def: Dictionary = {}
var tipo := ""             # carta, mazzo, tessera, standee, dado, sacchetto, vassoio, miniatura, modello, testo, libro, segnalino3d, ciotola
var faccia_su := true
var stato := 0             # per gli oggetti con più stati (pagine del Planetopedia, mappe dei sistemi)
var contenuto: Array = []  # mazzo: definizioni delle carte (la prima è in cima); sacchetto: definizioni degli oggetti
var infinito := false      # sacchetto che non si svuota mai (segnalini universali, carte grado)
var bloccato := false
var valore_dado := 0
var dim := Vector3.ONE     # larghezza, spessore, profondità
var scala := 1.0
var tavolo: Node           # riferimento al Tavolo

var _corpo: StaticBody3D
var _forma: CollisionShape3D
var _sopra: MeshInstance3D
var _sotto: MeshInstance3D
var _bordo: MeshInstance3D
var _etichetta: Label3D
var _evid: MeshInstance3D
var _mat_sopra: StandardMaterial3D
var _mat_sotto: StandardMaterial3D

static var _mesh_cache := {}

func _init(id_: String, def_: Dictionary, tipo_: String) -> void:
	id = id_
	def = def_
	tipo = tipo_
	name = "P_" + id_.validate_node_name()

## Definizione del lato visibile (per gli oggetti con più stati).
func def_attiva() -> Dictionary:
	if stato > 0 and def.has("stati"):
		var st: Array = def["stati"]
		if stato - 1 < st.size():
			return st[stato - 1]
	return def

func numero_stati() -> int:
	return 1 + def.get("stati", []).size()

func nome_visibile() -> String:
	var d := def_attiva()
	if tipo == "mazzo":
		var n := str(def.get("nome", "Mazzo"))
		return "%s (%d)" % [Traduzioni.nome(n), contenuto.size()]
	if tipo == "carta" and not faccia_su:
		return "Carta coperta"
	return Traduzioni.nome(str(d.get("nome", "")))

func costruisci() -> void:
	for c in get_children():
		c.queue_free()
	var t: Array = def.get("t", [0, 0, 0, 0, 0, 0, 1, 1, 1])
	scala = float(t[6]) if t.size() > 6 else 1.0
	_corpo = StaticBody3D.new()
	_corpo.set_meta("pezzo", self)
	add_child(_corpo)
	_forma = CollisionShape3D.new()
	_corpo.add_child(_forma)
	match tipo:
		"carta":
			_costruisci_piatto(_dim_carta(def), Color(0.08, 0.1, 0.14))
		"mazzo":
			_costruisci_mazzo()
		"tessera":
			_costruisci_tessera()
		"standee":
			_costruisci_standee()
		"dado":
			_costruisci_dado()
		"sacchetto":
			_costruisci_sacchetto()
		"vassoio":
			_costruisci_vassoio()
		"miniatura":
			_costruisci_miniatura()
		"modello":
			_costruisci_modello()
		"ciotola":
			_costruisci_ciotola()
		"testo":
			_costruisci_testo()
		"libro":
			_costruisci_libro()
		_:
			_costruisci_cubetto()
	_aggiorna_lato(false)

# ------------------------------------------------------------------ misure

## Misure di una carta dal rapporto larghezza/altezza dell'immagine (le carte orizzontali restano orizzontali).
func _dim_carta(d: Dictionary) -> Vector3:
	var ar := float(d.get("ar", 0.72))
	var s := scala
	if ar >= 1.0:
		return Vector3(CARTA_A * s, SPESSORE_CARTA, CARTA_A * s / ar)
	return Vector3(CARTA_L * s, SPESSORE_CARTA, CARTA_L * s / ar)

# ------------------------------------------------------------------ costruzione

func _quad(dimensioni: Vector2, mat: Material, sotto := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = dimensioni
	m.mesh = q
	m.material_override = mat
	if sotto:
		m.rotation = Vector3(PI, 0, 0)  # rivolto verso il basso, immagine non specchiata
	add_child(m)
	return m

func _mat(colore := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.roughness = 0.75
	m.metallic_specular = 0.25
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _costruisci_piatto(d: Vector3, colore_bordo: Color, trasparente := false) -> void:
	dim = d
	var b := BoxMesh.new()
	b.size = Vector3(d.x * 0.995, d.y, d.z * 0.995)
	_bordo = MeshInstance3D.new()
	_bordo.mesh = b
	_bordo.material_override = _mat(colore_bordo)
	if not trasparente:
		add_child(_bordo)
	_mat_sopra = _mat()
	_mat_sotto = _mat()
	if trasparente:
		for m in [_mat_sopra, _mat_sotto]:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.4
	_sopra = _quad(Vector2(d.x, d.z), _mat_sopra)
	_sopra.position.y = d.y * 0.5 + 0.0008
	_sotto = _quad(Vector2(d.x, d.z), _mat_sotto, true)
	_sotto.position.y = -d.y * 0.5 - 0.0008
	var sh := BoxShape3D.new()
	sh.size = Vector3(d.x, max(d.y, 0.02), d.z)
	_forma.shape = sh

func _costruisci_mazzo() -> void:
	var prima: Dictionary = contenuto[0] if not contenuto.is_empty() else def
	var d := _dim_carta(prima)
	d.y = max(SPESSORE_CARTA, contenuto.size() * SPESSORE_CARTA)
	_costruisci_piatto(d, Color(0.9, 0.9, 0.92))
	_etichetta_sopra(str(contenuto.size()), 0.5)

func _costruisci_tessera() -> void:
	var d := def_attiva()
	var ar := float(d.get("ar", def.get("ar", 1.0)))
	var sp := float(def.get("spessore", 0.1)) * scala * 0.6
	var v: Vector3
	if def.get("tipo", "") == "Custom_Tile":
		var corto := LATO_TESSERA * scala
		v = Vector3(corto * ar, sp, corto) if ar >= 1.0 else Vector3(corto, sp, corto / ar)
	else:
		var lungo := LATO_GETTONE * scala
		v = Vector3(lungo, sp, lungo / ar) if ar >= 1.0 else Vector3(lungo * ar, sp, lungo)
	# i gettoni sagomati (immagine con trasparenza) sono disegnati senza bordo a scatola
	_costruisci_piatto(v, Color(0.12, 0.14, 0.18), def.get("tipo", "") == "Custom_Token")
	if str(def.get("desc", "")) == "380" and str(def.get("nome", "")) != "":
		# targhe metalliche del Ship Book: nel modulo il nome compare solo al passaggio del mouse
		var l := Label3D.new()
		l.text = Traduzioni.nome(str(def["nome"])).to_upper()
		l.font = Tema.titolo
		l.font_size = 96
		l.pixel_size = 0.0045 * scala * 1.6
		l.modulate = Color(0.08, 0.1, 0.14)
		l.outline_size = 0
		l.rotation = Vector3(-PI / 2, 0, 0)
		l.position.y = v.y * 0.5 + 0.01
		add_child(l)

func _costruisci_standee() -> void:
	var ar := float(def.get("ar", 0.6))
	var h := 2.4 * scala
	var w := h * ar
	dim = Vector3(w, h, 0.4 * scala)
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = max(w, 0.8 * scala) * 0.45
	cil.bottom_radius = cil.top_radius
	cil.height = 0.12 * scala
	base.mesh = cil
	base.position.y = 0.06 * scala
	base.material_override = _mat(Color(0.05, 0.06, 0.08))
	add_child(base)
	_mat_sopra = _mat()
	_mat_sopra.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_mat_sopra.alpha_scissor_threshold = 0.4
	_mat_sopra.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	q.mesh = qm
	q.material_override = _mat_sopra
	q.position.y = h * 0.5 + 0.12 * scala
	q.rotation.y = PI  # rivolto verso il giocatore
	add_child(q)
	_sopra = q
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, h, 0.3 * scala)
	_forma.shape = sh
	_forma.position.y = h * 0.5
	Immagini.carica(str(def.get("img", "")), func(tex): if is_instance_valid(self): _mat_sopra.albedo_texture = tex)

func _costruisci_dado() -> void:
	var l := 0.9 * scala
	dim = Vector3(l, l, l)
	var m := MeshInstance3D.new()
	m.mesh = _mesh_dado(l)
	_mat_sopra = _mat(Color.WHITE if def.has("img") else Color(0.15, 0.15, 0.18))
	_mat_sopra.roughness = 0.4
	m.material_override = _mat_sopra
	add_child(m)
	_sopra = m
	var sh := BoxShape3D.new()
	sh.size = dim
	_forma.shape = sh
	_forma.position.y = l * 0.5
	m.position.y = l * 0.5
	if def.has("img"):
		Immagini.carica(str(def["img"]), func(tex): if is_instance_valid(self): _mat_sopra.albedo_texture = tex)
	else:
		_etichetta_sopra(str(valore_dado + 1), l + 0.05)

## Cubo con le facce prese dalla griglia 3×2 dell'immagine del dado TTS (riga alta vuota).
## La faccia 0 è quella in alto; ruotando il cubo si mostra il risultato.
func _mesh_dado(l: float) -> ArrayMesh:
	var h := l * 0.5
	# normali delle facce: su, giù, fronte(+z), retro(-z), destra(+x), sinistra(-x)
	var facce := [
		[Vector3.UP, Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(-h, h, h)],
		[Vector3.DOWN, Vector3(-h, -h, h), Vector3(h, -h, h), Vector3(h, -h, -h), Vector3(-h, -h, -h)],
		[Vector3.BACK, Vector3(-h, h, h), Vector3(h, h, h), Vector3(h, -h, h), Vector3(-h, -h, h)],
		[Vector3.FORWARD, Vector3(h, h, -h), Vector3(-h, h, -h), Vector3(-h, -h, -h), Vector3(h, -h, -h)],
		[Vector3.RIGHT, Vector3(h, h, h), Vector3(h, h, -h), Vector3(h, -h, -h), Vector3(h, -h, h)],
		[Vector3.LEFT, Vector3(-h, h, -h), Vector3(-h, h, h), Vector3(-h, -h, h), Vector3(-h, -h, -h)],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var f: Array = facce[i]
		var cx := float(i % 3) / 3.0
		var cy := (1.0 + float(i / 3)) / 3.0
		var uv := [Vector2(cx, cy), Vector2(cx + 1.0 / 3.0, cy), Vector2(cx + 1.0 / 3.0, cy + 1.0 / 3.0), Vector2(cx, cy + 1.0 / 3.0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(f[0])
			st.set_uv(uv[k])
			st.add_vertex(f[k + 1])
	return st.commit()

## Rotazione del cubo che porta in alto la faccia i.
func rotazione_faccia(i: int) -> Vector3:
	match i:
		0: return Vector3.ZERO
		1: return Vector3(PI, 0, 0)
		2: return Vector3(-PI / 2, 0, 0)
		3: return Vector3(PI / 2, 0, 0)
		4: return Vector3(0, 0, PI / 2)
		_: return Vector3(0, 0, -PI / 2)

func _costruisci_sacchetto() -> void:
	var s := scala
	dim = Vector3(1.6 * s, 1.4 * s, 1.6 * s)
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.55 * s
	c.bottom_radius = 0.8 * s
	c.height = 1.4 * s
	m.mesh = c
	var col: Array = def.get("colore", [0.5, 0.5, 0.5])
	var mt := _mat(Color(col[0], col[1], col[2]).darkened(0.25))
	mt.roughness = 0.95
	m.material_override = mt
	m.position.y = 0.7 * s
	add_child(m)
	var nodo := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42 * s
	t.outer_radius = 0.6 * s
	nodo.mesh = t
	nodo.position.y = 1.3 * s
	nodo.material_override = _mat(Color(col[0], col[1], col[2]).darkened(0.5))
	add_child(nodo)
	var sh := CylinderShape3D.new()
	sh.radius = 0.8 * s
	sh.height = 1.4 * s
	_forma.shape = sh
	_forma.position.y = 0.7 * s
	_etichetta_sopra(Traduzioni.nome(str(def.get("nome", ""))), 1.75 * s, 0.9)

func _costruisci_vassoio() -> void:
	var t: Array = def.get("t", [])
	var sx := float(t[6]) if t.size() > 8 else 1.0
	var sz := float(t[8]) if t.size() > 8 else 1.0
	dim = Vector3(6.0 * sx, 0.12, 6.0 * sz)
	var col: Array = def.get("colore", [0.1, 0.25, 0.47])
	var c := Color(col[0], col[1], col[2])
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(dim.x, 0.06, dim.z)
	m.mesh = b
	var mt := _mat(c.darkened(0.55))
	mt.metallic = 0.6
	mt.roughness = 0.45
	m.material_override = mt
	m.position.y = 0.03
	add_child(m)
	# cornice luminosa
	for lato in 4:
		var e := MeshInstance3D.new()
		var eb := BoxMesh.new()
		var orizz := lato < 2
		eb.size = Vector3(dim.x if orizz else 0.12, 0.14, 0.12 if orizz else dim.z)
		e.mesh = eb
		var em := _mat(c)
		em.emission_enabled = true
		em.emission = c.lightened(0.2)
		em.emission_energy_multiplier = 0.6
		e.material_override = em
		e.position = Vector3(0 if orizz else (dim.x * 0.5 if lato == 2 else -dim.x * 0.5), 0.07,
			(dim.z * 0.5 if lato == 0 else -dim.z * 0.5) if orizz else 0)
		add_child(e)
	var sh := BoxShape3D.new()
	sh.size = Vector3(dim.x, 0.1, dim.z)
	_forma.shape = sh
	var n := Traduzioni.nome(str(def.get("nome", "")))
	if n != "":
		_etichetta = Label3D.new()
		_etichetta.text = n.to_upper()
		_etichetta.font = Tema.titolo
		_etichetta.font_size = 64
		_etichetta.pixel_size = 0.006
		_etichetta.modulate = c.lightened(0.5)
		_etichetta.outline_size = 0
		_etichetta.rotation = Vector3(-PI / 2, 0, 0)
		_etichetta.position = Vector3(0, 0.08, dim.z * 0.5 - 0.35)
		add_child(_etichetta)

func _costruisci_miniatura() -> void:
	var b := str(def.get("bundle", ""))
	var nome := "capitano"
	if b.contains("4644286"): nome = "esploratore"
	elif b.contains("4645247"): nome = "pilota"
	elif b.contains("4646529"): nome = "soldato"
	var mesh: Mesh = _carica_mesh("res://assets/modelli/%s.obj" % nome)
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mt := _mat()
	mt.albedo_texture = load("res://assets/modelli/%s.png" % nome)
	mt.roughness = 0.55
	m.material_override = mt
	# i modelli Unity sono alti pochi centimetri: si portano a ~1,9 unità
	var aabb := mesh.get_aabb() if mesh else AABB(Vector3.ZERO, Vector3.ONE)
	var k: float = 1.9 / maxf(aabb.size.y, 0.001)
	m.scale = Vector3(-k, k, k)  # x ribaltato: da mano sinistra (Unity) a mano destra
	m.position.y = -aabb.position.y * k
	m.rotation.y = PI
	add_child(m)
	dim = Vector3(aabb.size.x * k, 1.9, aabb.size.z * k)
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.45
	cil.bottom_radius = 0.48
	cil.height = 0.08
	base.mesh = cil
	base.material_override = _mat(Color(0.06, 0.07, 0.09))
	base.position.y = 0.04
	add_child(base)
	var sh := CylinderShape3D.new()
	sh.radius = 0.5
	sh.height = 1.9
	_forma.shape = sh
	_forma.position.y = 0.95

func _costruisci_modello() -> void:
	var mesh_file := str(def.get("mesh", ""))
	var p := ""
	if mesh_file.contains("9383112666"): p = "res://assets/modelli/scatola.obj"
	elif mesh_file.contains("17603248104"): p = "res://assets/modelli/vassoio_dadi.obj"
	var s := scala
	var mesh: Mesh = _carica_mesh(p) if p != "" else null
	if mesh == null:
		_costruisci_sacchetto()
		return
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mt := _mat()
	m.material_override = mt
	m.scale = Vector3(s, s, s)
	add_child(m)
	Immagini.carica(str(def.get("img", "")), func(tex): if is_instance_valid(self): mt.albedo_texture = tex)
	var aabb := mesh.get_aabb()
	dim = aabb.size * s
	var sh := BoxShape3D.new()
	sh.size = dim
	_forma.shape = sh
	_forma.position.y = (aabb.position.y + aabb.size.y * 0.5) * s
	if def.get("tipo", "") == "Custom_Model_Bag":
		_etichetta_sopra(Traduzioni.nome(str(def.get("nome", ""))), dim.y + 0.25, 0.9)

func _costruisci_ciotola() -> void:
	var s := scala * 1.6
	dim = Vector3(2.4 * s, 0.6 * s, 2.4 * s)
	var col: Array = def.get("colore", [0.3, 0.3, 0.35])
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 1.2 * s
	c.bottom_radius = 0.95 * s
	c.height = 0.5 * s
	m.mesh = c
	var mt := _mat(Color(col[0], col[1], col[2]).darkened(0.3))
	mt.metallic = 0.5
	m.material_override = mt
	m.position.y = 0.25 * s
	add_child(m)
	var sh := CylinderShape3D.new()
	sh.radius = 1.2 * s
	sh.height = 0.5 * s
	_forma.shape = sh
	_forma.position.y = 0.25 * s
	_etichetta_sopra(Traduzioni.nome(str(def.get("nome", ""))), 0.65 * s, 0.9)

func _costruisci_testo() -> void:
	dim = Vector3(1.5, 0.05, 0.5)
	_etichetta = Label3D.new()
	var t := str(def.get("testo", ""))
	_etichetta.text = "" if t == "Type Here" else t
	_etichetta.font = Tema.testo_grassetto
	_etichetta.font_size = 48
	_etichetta.pixel_size = 0.008
	_etichetta.rotation = Vector3(-PI / 2, 0, 0)
	_etichetta.position.y = 0.05
	add_child(_etichetta)
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.5, 0.05, 0.5)
	_forma.shape = sh

func _costruisci_libro() -> void:
	var t: Array = def.get("t", [])
	var s := float(t[6]) if t.size() > 6 else 1.0
	_costruisci_piatto(Vector3(1.6 * s, 0.25, 2.1 * s), Color(0.15, 0.3, 0.5))
	_mat_sopra.albedo_color = Color(0.08, 0.16, 0.3)
	_etichetta_sopra("REGOLE" if str(def.get("pdf", "")).contains("BD873") or str(def.get("pdf", "")).contains("9AB9179") else "LOGBOOK", 0.2, 1.4)

func _costruisci_cubetto() -> void:
	var s := scala
	var col: Array = def.get("colore", [0.6, 0.2, 0.9])
	dim = Vector3(0.7 * s, 0.7 * s, 0.7 * s)
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = dim
	m.mesh = b
	m.material_override = _mat(Color(col[0], col[1], col[2]))
	m.position.y = dim.y * 0.5
	add_child(m)
	var sh := BoxShape3D.new()
	sh.size = dim
	_forma.shape = sh
	_forma.position.y = dim.y * 0.5

func _carica_mesh(p: String) -> Mesh:
	if p == "":
		return null
	if _mesh_cache.has(p):
		return _mesh_cache[p]
	var m: Mesh = load(p) if ResourceLoader.exists(p) else null
	_mesh_cache[p] = m
	return m

func _etichetta_sopra(t: String, h: float, k := 1.0) -> void:
	if t == "":
		return
	_etichetta = Label3D.new()
	_etichetta.text = t
	_etichetta.font = Tema.titolo
	_etichetta.font_size = 40
	_etichetta.pixel_size = 0.006 * k
	_etichetta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etichetta.no_depth_test = false
	_etichetta.outline_size = 10
	_etichetta.outline_modulate = Color(0, 0, 0, 0.8)
	_etichetta.position.y = h
	_etichetta.visible = tipo in ["sacchetto", "ciotola", "libro", "modello"]
	add_child(_etichetta)

# ------------------------------------------------------------------ aspetto

func _aggiorna_lato(anima := true) -> void:
	match tipo:
		"carta":
			_texture(_mat_sopra, str(def.get("fronte", "")))
			_texture(_mat_sotto, str(def.get("retro", "")))
		"mazzo":
			if contenuto.is_empty():
				return
			var cima: Dictionary = contenuto[0]
			var fondo: Dictionary = contenuto[-1]
			# mazzo coperto: in alto il retro della prima carta; sotto il fronte dell'ultima
			_texture(_mat_sopra, str(cima.get("retro" if not faccia_su else "fronte", "")))
			_texture(_mat_sotto, str(fondo.get("fronte" if not faccia_su else "retro", "")))
			if _etichetta:
				_etichetta.text = str(contenuto.size())
		"tessera":
			var d := def_attiva()
			_texture(_mat_sopra, str(d.get("img", "")))
			_texture(_mat_sotto, str(d.get("img2", d.get("img", ""))))
	if tipo == "mazzo":
		return
	var rz := 0.0 if faccia_su else PI
	if tipo in ["carta", "tessera"]:
		if anima and is_inside_tree():
			var tw := create_tween()
			tw.tween_property(self, "rotation:z", rz, 0.18)
		else:
			rotation.z = rz

func _texture(m: StandardMaterial3D, rel: String) -> void:
	if m == null:
		return
	if rel == "":
		m.albedo_texture = null
		return
	var t := Immagini.subito(rel)
	if t:
		m.albedo_texture = t
		m.albedo_color = Color.WHITE
		return
	# finché l'immagine non arriva il pezzo resta scuro (non un rettangolo bianco)
	m.albedo_color = Color(0.1, 0.14, 0.2)
	Immagini.carica(rel, func(tex):
		if is_instance_valid(self) and m:
			m.albedo_texture = tex
			m.albedo_color = Color.WHITE)

## Immagine da mostrare ingrandita (lato visibile).
func immagine_visibile() -> String:
	match tipo:
		"carta":
			return str(def.get("fronte" if faccia_su else "retro", ""))
		"mazzo":
			if contenuto.is_empty(): return ""
			return str(contenuto[0].get("fronte" if faccia_su else "retro", ""))
		"tessera":
			var d := def_attiva()
			return str(d.get("img" if faccia_su else "img2", d.get("img", "")))
		"standee":
			return str(def.get("img", ""))
	return ""

func evidenzia(on: bool, colore := Tema.CIANO) -> void:
	if on and _evid == null:
		_evid = MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(dim.x + 0.12, 0.02, (dim.z if tipo not in ["standee", "dado", "miniatura"] else dim.z) + 0.12)
		_evid.mesh = b
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(colore, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_evid.material_override = m
		_evid.position.y = -dim.y * 0.5 - 0.01 if tipo in ["carta", "mazzo", "tessera"] else 0.01
		add_child(_evid)
	elif not on and _evid:
		_evid.queue_free()
		_evid = null
	if _etichetta and tipo not in ["vassoio", "testo"]:
		_etichetta.visible = on or tipo in ["sacchetto", "ciotola", "libro", "modello"]

# ------------------------------------------------------------------ azioni

func gira() -> void:
	if tipo in ["carta", "tessera", "mazzo"]:
		faccia_su = not faccia_su
		if tipo == "mazzo":
			contenuto.reverse()
		_aggiorna_lato()

func ruota(gradi: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", rotation.y + deg_to_rad(gradi), 0.15)

func cambia_stato(n := -1) -> void:
	var tot := numero_stati()
	if tot <= 1:
		return
	stato = (stato + 1) % tot if n < 0 else clampi(n, 0, tot - 1)
	costruisci()

func mescola() -> void:
	if tipo == "mazzo":
		contenuto.shuffle()
		_aggiorna_lato(false)
		var tw := create_tween()
		tw.tween_property(self, "rotation:y", rotation.y + TAU, 0.35)

## Tira il dado: animazione, poi la faccia scelta a caso in alto.
func tira() -> int:
	if tipo != "dado":
		return -1
	valore_dado = randi() % 6 if def.has("img") else randi() % (10 if def.get("tipo", "") == "Die_10" else 6)
	var tw := create_tween()
	var giri := Vector3(randf_range(3, 6) * TAU, randf_range(1, 3) * TAU, randf_range(3, 6) * TAU)
	position.y += 1.2
	tw.tween_property(_sopra, "rotation", giri, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "position:y", position.y - 1.2, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sopra, "rotation", rotazione_faccia(valore_dado) if def.has("img") else Vector3.ZERO, 0.12)
	if not def.has("img") and _etichetta:
		_etichetta.text = str(valore_dado + 1)
	return valore_dado

func imposta_faccia_dado(v: int) -> void:
	valore_dado = v
	if _sopra and tipo == "dado":
		_sopra.rotation = rotazione_faccia(v) if def.has("img") else Vector3.ZERO
		if not def.has("img") and _etichetta:
			_etichetta.text = str(v + 1)

## Prende la carta in cima a un mazzo (restituisce la definizione) e aggiorna il mazzo.
func pesca() -> Dictionary:
	if tipo != "mazzo" or contenuto.is_empty():
		return {}
	var c: Dictionary = contenuto.pop_front()
	_ricostruisci_mazzo()
	return c

func aggiungi_in_cima(c: Dictionary) -> void:
	contenuto.push_front(c)
	_ricostruisci_mazzo()

func aggiungi_in_fondo(c: Dictionary) -> void:
	contenuto.push_back(c)
	_ricostruisci_mazzo()

func _ricostruisci_mazzo() -> void:
	var r := rotation
	costruisci()
	rotation = r

func altezza() -> float:
	match tipo:
		"carta", "mazzo", "tessera":
			return dim.y
		_:
			return dim.y

## Stato da salvare.
func serializza() -> Dictionary:
	var d := {"id": id, "p": [snappedf(position.x, 0.001), snappedf(position.y, 0.001), snappedf(position.z, 0.001)],
		"r": snappedf(rad_to_deg(rotation.y), 0.1)}
	if not faccia_su: d["f"] = 0
	if stato: d["s"] = stato
	if bloccato: d["b"] = 1
	if tipo == "dado": d["v"] = valore_dado
	if tipo == "carta" and not is_equal_approx(scala, 1.0): d["k"] = snappedf(scala, 0.001)
	if tipo in ["mazzo", "sacchetto"] and not infinito:
		d["c"] = contenuto.map(func(x): return str(x.get("_id", "")))
	return d

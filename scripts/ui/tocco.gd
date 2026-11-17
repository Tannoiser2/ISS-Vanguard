## Gesti a due dita per le viste (iPad e telefoni): pizzico = zoom, due dita che girano = rotazione,
## due dita che scorrono = spostamento. Un dito solo resta al mouse emulato (trascina = sposta, tocco = clic).
## Uso: var g := _tocco.evento(e) -> {} se l'evento non riguarda due dita, altrimenti
## {"centro": Vector2, "sposta": Vector2, "zoom": float (>1 = avvicina), "ruota": float (radianti)}.
class_name Tocco
extends RefCounted

var dita := {}            # indice -> posizione
var _dist := 0.0
var _ang := 0.0
var _centro := Vector2.ZERO

## true mentre ci sono almeno due dita: in quel momento il mouse emulato va ignorato.
func attivo() -> bool:
	return dita.size() >= 2

func evento(e: InputEvent) -> Dictionary:
	if e is InputEventScreenTouch:
		var t: InputEventScreenTouch = e
		if t.pressed:
			dita[t.index] = t.position
		else:
			dita.erase(t.index)
		_riparti()
		return {"inizio": true} if dita.size() >= 2 else {}
	if e is InputEventScreenDrag:
		var d: InputEventScreenDrag = e
		if not dita.has(d.index):
			dita[d.index] = d.position
			_riparti()
			return {}
		dita[d.index] = d.position
		if dita.size() < 2:
			return {}
		var p := _due()
		var a: Vector2 = p[0]
		var b: Vector2 = p[1]
		var dist := a.distance_to(b)
		var ang := (b - a).angle()
		var centro := (a + b) * 0.5
		var out := {
			"centro": centro,
			"sposta": centro - _centro,
			"zoom": dist / maxf(1.0, _dist),
			"ruota": wrapf(ang - _ang, -PI, PI),
		}
		_dist = dist
		_ang = ang
		_centro = centro
		return out
	return {}

func _due() -> Array:
	var k := dita.keys()
	k.sort()
	return [dita[k[0]], dita[k[1]]]

func _riparti() -> void:
	if dita.size() >= 2:
		var p := _due()
		var a: Vector2 = p[0]
		var b: Vector2 = p[1]
		_dist = a.distance_to(b)
		_ang = (b - a).angle()
		_centro = (a + b) * 0.5

## Caricatore delle immagini grandi (carte, plance, pagine delle regole).
## Non stanno nel pacchetto .pck: sono file webp nella cartella web/img del repository,
## pubblicati accanto al gioco su GitHub Pages e scaricati solo quando servono.
## - nella versione web: richiesta HTTP all'indirizzo della pagina (img/...)
## - nell'editor o in una copia locale del progetto: lettura diretta da res://web/img
## - in un eseguibile esportato senza la cartella: scaricate dal sito pubblicato
extends Node

const SITO := "https://tannoiser2.github.io/ISS-Vanguard/"
const MAX_PARALLELE := 12

signal pronta(rel: String, tex: Texture2D)

var _cache := {}        # rel -> Texture2D
var _attesa := {}       # rel -> Array[Callable]
var _coda: Array[String] = []
var _attive := 0
var _base := ""
var _locale := ""

func _ready() -> void:
	if OS.has_feature("web"):
		var href = JavaScriptBridge.eval("location.href.split('?')[0].split('#')[0]")
		_base = str(href).get_base_dir() + "/"
	else:
		var p := ProjectSettings.globalize_path("res://web/img")
		if DirAccess.dir_exists_absolute(p):
			_locale = p + "/"
		_base = SITO

## Texture già in memoria (oppure null).
func subito(rel: String) -> Texture2D:
	return _cache.get(rel)

## Chiede un'immagine: cb(tex) viene chiamata appena è pronta (anche subito se già in memoria).
func carica(rel: String, cb: Callable) -> void:
	if rel == "":
		return
	if _cache.has(rel):
		cb.call(_cache[rel])
		return
	if _attesa.has(rel):
		_attesa[rel].append(cb)
		return
	_attesa[rel] = [cb]
	if _locale != "":
		var img := Image.load_from_file(_locale + rel)
		_fine(rel, img)
		return
	_coda.append(rel)
	_avanza()

## Versione con await.
func attendi(rel: String) -> Texture2D:
	if _cache.has(rel):
		return _cache[rel]
	var out: Array = [null, false]
	carica(rel, func(t): out[0] = t; out[1] = true)
	while not out[1]:
		await pronta
	return out[0]

func _avanza() -> void:
	while _attive < MAX_PARALLELE and not _coda.is_empty():
		var rel: String = _coda.pop_back()  # le ultime richieste sono quelle che servono ora
		_attive += 1
		_scarica(rel)

func _scarica(rel: String) -> void:
	var http := HTTPRequest.new()
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)
	http.request(_base + "img/" + rel.uri_encode().replace("%2F", "/"))
	var res: Array = await http.request_completed
	http.queue_free()
	_attive -= 1
	var img: Image = null
	if res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200:
		img = Image.new()
		if img.load_webp_from_buffer(res[3]) != OK:
			img = null
	_fine(rel, img)
	_avanza()

func _fine(rel: String, img: Image) -> void:
	var tex: Texture2D = null
	if img != null and not img.is_empty():
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	else:
		push_warning("Immagine non trovata: " + rel)
	_cache[rel] = tex
	var cbs: Array = _attesa.get(rel, [])
	_attesa.erase(rel)
	for cb in cbs:
		if cb.is_valid():
			cb.call(tex)
	pronta.emit(rel, tex)

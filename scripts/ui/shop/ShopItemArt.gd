extends RefCounted
## Original object illustrations on a 28-pixel grid. Colours describe the objects,
## not Shop state: both art sizes stay identical across presentation preferences.

const INK := Color("293b43")
const PAPER := Color("e4dcc2")
const LIGHT := Color("f2ebd8")
const SAND := Color("c8a776")
const WOOD := Color("8e6850")
const SAGE := Color("859b8b")
const ROSE := Color("b7817d")
const SLATE := Color("78919e")

static func texture(item_id: String, size: int) -> Texture2D:
	if size not in [28, 56]: return null
	var strokes: Array = []
	match item_id:
		"crystal_stutters":
			strokes = [
				[9, 3, 10, 2, INK], [6, 5, 16, 3, INK], [4, 8, 20, 9, INK],
				[7, 17, 14, 4, INK], [10, 21, 8, 3, INK], [13, 24, 2, 2, INK],
				[10, 5, 8, 3, LIGHT], [7, 8, 14, 8, SLATE], [10, 16, 8, 5, SLATE],
				[13, 8, 2, 14, PAPER], [8, 9, 3, 4, LIGHT], [17, 9, 3, 6, SAGE],
			]
		"inked_silk_string":
			strokes = [
				[7, 4, 14, 3, INK], [9, 7, 10, 14, WOOD], [7, 21, 14, 3, INK],
				[10, 7, 8, 2, SLATE], [10, 11, 8, 2, SLATE], [10, 15, 8, 2, SLATE],
				[10, 19, 8, 2, SLATE], [18, 13, 5, 1, INK], [22, 14, 1, 7, INK],
				[20, 21, 3, 1, INK], [19, 22, 2, 3, INK], [8, 5, 12, 1, PAPER],
			]
		"letter_with_wax_seal":
			strokes = [
				[3, 6, 22, 17, INK], [4, 7, 20, 15, PAPER], [5, 8, 3, 2, WOOD],
				[8, 10, 3, 2, WOOD], [11, 12, 6, 2, WOOD], [17, 10, 3, 2, WOOD],
				[20, 8, 3, 2, WOOD], [10, 14, 8, 6, INK], [11, 13, 6, 8, INK],
				[11, 15, 6, 4, ROSE], [12, 14, 4, 6, ROSE], [13, 16, 2, 2, PAPER],
			]
		"lucky_charm":
			strokes = [
				[10, 3, 3, 3, INK], [15, 3, 3, 3, INK],
				[11, 4, 1, 1, SAND], [16, 4, 1, 1, SAND], [12, 6, 4, 3, INK],
				[9, 9, 10, 2, INK], [7, 11, 14, 10, INK], [9, 21, 10, 2, INK],
				[10, 10, 8, 11, ROSE], [8, 12, 12, 8, ROSE],
				[9, 11, 10, 2, SAND], [11, 15, 6, 4, PAPER],
				[13, 22, 2, 3, WOOD], [11, 25, 6, 1, SAND],
			]
		"debug_key":
			strokes = [
				[5, 5, 9, 2, INK], [3, 7, 13, 7, INK], [5, 14, 9, 2, INK],
				[5, 7, 9, 7, SAND], [7, 8, 5, 5, INK], [8, 9, 3, 3, PAPER],
				[13, 11, 12, 5, INK], [14, 12, 10, 3, SAND], [15, 12, 8, 1, LIGHT],
				[18, 16, 3, 4, INK], [23, 16, 2, 4, INK],
				[19, 15, 1, 4, SAND], [24, 15, 1, 4, SAND],
			]
		"bookend_keepsake":
			strokes = [
				[4, 5, 5, 19, INK], [5, 6, 3, 17, WOOD],
				[4, 23, 20, 2, INK], [9, 22, 15, 1, SAND],
				[10, 3, 12, 19, INK], [11, 4, 10, 17, SLATE],
				[12, 4, 2, 17, SAGE], [16, 6, 5, 1, PAPER],
				[16, 9, 4, 1, PAPER], [11, 19, 10, 2, PAPER], [12, 20, 8, 1, SAND],
			]
		"metronome_keepsake":
			strokes = [
				[11, 2, 6, 4, INK], [9, 6, 10, 5, INK], [7, 11, 14, 6, INK],
				[5, 17, 18, 8, INK], [12, 3, 4, 3, WOOD], [10, 6, 8, 5, WOOD],
				[8, 11, 12, 6, WOOD], [6, 17, 16, 7, WOOD],
				[12, 6, 4, 12, PAPER], [10, 11, 2, 1, SAND], [10, 15, 2, 1, SAND],
				[13, 9, 1, 12, INK], [14, 6, 1, 4, INK], [15, 4, 1, 3, INK],
				[12, 10, 4, 3, SLATE], [11, 19, 6, 2, SAND], [7, 23, 14, 1, SAND],
			]
		"pocket_calculator_keepsake":
			strokes = [
				[6, 2, 16, 24, INK], [7, 3, 14, 22, SLATE],
				[8, 4, 12, 6, INK], [9, 5, 10, 4, SAGE], [16, 6, 2, 2, PAPER],
				[9, 12, 2, 2, PAPER], [13, 12, 2, 2, PAPER], [17, 12, 2, 2, ROSE],
				[9, 16, 2, 2, PAPER], [13, 16, 2, 2, PAPER], [17, 16, 2, 2, PAPER],
				[9, 20, 2, 2, PAPER], [13, 20, 2, 2, PAPER], [17, 20, 2, 3, SAND],
			]

	# Unknown IDs (including the intentionally blank Supportz slot) have no art.
	if strokes.is_empty(): return null
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var step := 1 if size == 28 else 2
	for stroke: Array in strokes:
		image.fill_rect(Rect2i(stroke[0] * step, stroke[1] * step,
			stroke[2] * step, stroke[3] * step), stroke[4])
	return ImageTexture.create_from_image(image)


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
const RED := Color("a7353d")

static func texture(item_id: String, size: int) -> Texture2D:
	if size not in [28, 56]: return null
	var strokes: Array = []
	match item_id:
		# Original plush and bandage illustrations from 8630b25b (2026-09-21).
		"lucky_charm":
			strokes = [
				[5, 3, 5, 5, INK], [18, 3, 5, 5, INK],
				[6, 4, 3, 3, WOOD], [19, 4, 3, 3, WOOD],
				[8, 5, 12, 2, INK], [6, 7, 16, 9, INK], [7, 7, 14, 8, SAND],
				[9, 9, 2, 2, INK], [17, 9, 2, 2, INK],
				[11, 12, 6, 3, PAPER], [13, 12, 2, 1, INK],
				[7, 16, 14, 8, INK], [8, 16, 12, 7, SAND], [11, 17, 6, 5, PAPER],
				[3, 18, 6, 7, INK], [19, 18, 6, 7, INK],
				[4, 19, 4, 5, WOOD], [20, 19, 4, 5, WOOD],
			]
		"debug_key":
			strokes = [
				[4, 4, 15, 19, INK], [5, 5, 13, 17, PAPER],
				[5, 5, 13, 3, SLATE], [7, 10, 8, 1, WOOD], [7, 12, 5, 1, WOOD],
				[11, 15, 14, 7, INK], [12, 16, 12, 5, SAND],
				[16, 17, 4, 3, LIGHT], [13, 18, 1, 1, WOOD], [22, 18, 1, 1, WOOD],
			]
		"crystal_stutters":
			strokes = [
				[13, 2, 2, 3, INK], [12, 5, 4, 4, INK], [11, 9, 6, 2, INK],
				[13, 4, 1, 4, LIGHT], [12, 8, 3, 2, SLATE],
				[2, 12, 3, 2, INK], [5, 11, 4, 4, INK], [9, 10, 2, 6, INK],
				[4, 12, 4, 1, LIGHT], [7, 13, 3, 1, SLATE],
				[17, 10, 2, 6, INK], [19, 11, 4, 4, INK], [23, 12, 3, 2, INK],
				[18, 11, 2, 3, SLATE], [20, 12, 3, 1, LIGHT],
				[11, 17, 6, 2, INK], [12, 19, 4, 4, INK], [13, 23, 2, 3, INK],
				[12, 18, 3, 1, LIGHT], [13, 19, 2, 4, SLATE],
				[12, 12, 4, 4, INK], [13, 12, 2, 3, LIGHT], [12, 14, 2, 2, SLATE],
				[5, 4, 3, 3, INK], [6, 5, 1, 1, LIGHT],
				[21, 21, 2, 3, INK], [21, 21, 1, 2, SLATE],
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
				[20, 8, 3, 2, WOOD], [12, 14, 4, 3, RED], [13, 13, 2, 5, RED],
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

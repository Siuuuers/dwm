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
		"wine":
			strokes = [
				[11, 2, 6, 8, INK], [12, 3, 4, 3, ROSE], [12, 7, 4, 4, SAGE],
				[9, 10, 10, 2, INK], [8, 12, 12, 13, INK],
				[9, 12, 10, 12, SAGE], [10, 12, 2, 4, LIGHT],
				[9, 17, 10, 5, PAPER], [12, 18, 4, 3, ROSE],
			]
		"pineapple_bun":
			strokes = [
				[9, 5, 10, 2, INK], [6, 7, 16, 3, INK], [4, 10, 20, 4, INK],
				[3, 14, 22, 6, INK], [5, 20, 18, 3, INK],
				[9, 7, 10, 2, SAND], [6, 9, 16, 4, SAND], [5, 13, 18, 7, SAND],
				[6, 20, 16, 2, WOOD], [7, 16, 14, 2, WOOD],
				[7, 11, 3, 1, PAPER], [10, 9, 3, 1, PAPER], [13, 7, 2, 1, PAPER],
				[9, 14, 3, 1, PAPER], [12, 12, 3, 1, PAPER], [15, 10, 3, 1, PAPER],
				[13, 15, 3, 1, WOOD], [16, 13, 3, 1, WOOD], [19, 11, 2, 1, WOOD],
				[9, 9, 1, 2, WOOD], [11, 11, 1, 2, WOOD], [13, 13, 1, 2, WOOD],
				[15, 15, 1, 2, WOOD], [15, 8, 1, 2, WOOD], [17, 10, 1, 2, WOOD],
			]
		"quiet_tea":
			strokes = [
				[10, 3, 1, 3, SAGE], [11, 2, 1, 1, SAGE],
				[15, 4, 1, 3, SAGE], [16, 3, 1, 1, SAGE],
				[5, 10, 15, 10, INK], [20, 11, 5, 7, INK], [20, 13, 3, 3, PAPER],
				[6, 11, 13, 7, PAPER], [7, 11, 11, 2, WOOD], [7, 14, 2, 3, LIGHT],
				[7, 19, 11, 2, INK], [2, 22, 24, 1, INK],
				[4, 21, 20, 1, SAGE], [5, 23, 18, 1, INK],
			]
		"soft_blanket":
			strokes = [
				[4, 6, 20, 17, INK], [5, 7, 18, 15, SLATE],
				[5, 7, 18, 4, PAPER], [5, 11, 18, 1, INK],
				[7, 13, 14, 1, SAGE], [7, 17, 14, 1, SAGE],
				[8, 12, 1, 9, SAGE], [18, 12, 1, 9, SAGE],
				[6, 22, 2, 3, PAPER], [10, 22, 2, 3, PAPER],
				[14, 22, 2, 3, PAPER], [18, 22, 2, 3, PAPER], [22, 22, 1, 3, PAPER],
			]
		"weighted_plush":
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
		"spa_coupon":
			strokes = [
				[4, 6, 20, 16, INK], [2, 8, 2, 4, INK], [2, 16, 2, 4, INK],
				[24, 8, 2, 4, INK], [24, 16, 2, 4, INK],
				[5, 7, 18, 14, PAPER], [3, 9, 2, 2, PAPER], [3, 17, 2, 2, PAPER],
				[23, 9, 2, 2, PAPER], [23, 17, 2, 2, PAPER],
				[7, 10, 9, 3, SAGE], [7, 16, 8, 1, WOOD], [7, 18, 6, 1, WOOD],
				[19, 9, 1, 2, SAND], [19, 13, 1, 2, SAND], [19, 17, 1, 2, SAND],
			]
		"premium_care":
			strokes = [
				[6, 5, 10, 5, INK], [8, 7, 6, 3, PAPER],
				[3, 10, 17, 14, INK], [4, 11, 15, 12, SAGE],
				[4, 14, 15, 1, INK], [10, 13, 3, 3, SAND],
				[20, 7, 5, 4, INK], [19, 11, 7, 13, INK],
				[20, 12, 5, 11, PAPER], [20, 16, 5, 5, ROSE], [21, 12, 1, 3, LIGHT],
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


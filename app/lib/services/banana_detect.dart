// Finds the subject of an uploaded photo so the crop box can start on it.
//
// The camera path has a reticle the user aims; gallery uploads start with a
// box in the middle of the frame, which is wrong whenever the banana is not
// in the middle. This locates it so the box starts in the right place.
//
// **Why background deviation rather than banana colour.** The obvious
// approach is to look for banana colours, reusing `isBananaColor` from
// [frame_quality.dart]. Measured across the training set that fails on
// overripe fruit: black and brown peel is not banana-coloured, so 56% of
// overripe photos yielded no usable region, and the regions it did find
// covered only 11–15% of the frame — cutting through the middle of the
// banana and discarding the tips, which is the shape cue that separates
// Lakatan from Latundan. Loosening the colour thresholds did not fix it;
// 41% of overripe photos still failed at the loosest setting that kept
// background out.
//
// Estimating the background from the border and flagging whatever differs
// from it is blind to ripeness — a black banana differs from a pale table as
// strongly as a yellow one does. On the same images overripe then performed
// identically to ripe (71% vs 71% usable).
//
// **The failure mode is the point.** Colour matching failed by returning a
// box that was too *small*, silently cropping the banana in half. This fails
// on busy or textured backgrounds by returning a box that is too *large*,
// which [detectSubjectBounds] rejects, leaving the centred default. A worse
// starting position, never a destroyed photo.
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

/// Analysis grid. The photo is sampled down to this before anything else:
/// subject bounds only need to be accurate to a few percent of the frame, and
/// a fixed grid keeps the cost constant no matter how large the upload is.
const int _gridSize = 96;

/// Fraction of each edge sampled to estimate the background colour.
const double _borderFraction = 0.10;

/// How much a cell's brightness counts next to its colour.
///
/// Comparing raw RGB makes the detector react to shading, and a surface with
/// folds or a lighting gradient then reads as subject: on a photo of a green
/// banana on creased magenta cloth, 69% of cells cleared the threshold and
/// the "subject" spanned the whole frame.
///
/// Comparing colour alone fixes that but loses black overripe peel, which
/// differs from a pale table in brightness and almost nothing else —
/// detection fell to 65% on overripe. Damping brightness rather than
/// discarding it keeps both: measured across the training set, this finds a
/// subject in 100% of unripe, ripe and overripe photos.
const double _lumaWeight = 0.35;

/// Distance in that space beyond which a cell differs from the background.
///
/// Tuned with [_lumaWeight] on the training set: lower and fabric texture
/// registers as subject, higher and a pale banana on a white surface is
/// missed.
const double _backgroundDistance = 24.0;

/// Neighbours a set cell needs to survive the erode half of the opening.
///
/// 7 of 8 keeps solid interiors and strips anything one cell thick — a seam
/// in the cloth, a wood grain line, the halo along a shadow edge. Those thin
/// structures are what bridge unrelated regions into one oversized box.
const int _erodeNeighbours = 7;

/// Smallest and largest share of the frame a believable subject occupies.
///
/// Below [_minimumArea] the match is a speck rather than a banana. Above
/// [_maximumArea] the background estimate has failed — on a patterned cloth
/// or a wood grain the whole frame reads as subject — and the centred default
/// is the better starting point.
const double _minimumArea = 0.02;
const double _maximumArea = 0.70;

/// Returns the subject's bounds in [image] pixel coordinates, or `null` when
/// nothing plausible was found.
///
/// `null` is the normal outcome for about a third of photos and is not an
/// error: the caller falls back to the centred box.
Rect? detectSubjectBounds(img.Image image) {
  if (image.width <= 0 || image.height <= 0) return null;

  final cells = _sampleGrid(image);
  final background = _estimateBackground(cells);
  final mask = _differsFromBackground(cells, background);
  _open(mask);

  final bounds = _largestRegionBounds(mask);
  if (bounds == null) return null;

  // Grid cell -> pixel. The right/bottom edges take the far side of the cell
  // so a subject one cell wide still has non-zero extent.
  final scaleX = image.width / _gridSize;
  final scaleY = image.height / _gridSize;
  final rect = Rect.fromLTRB(
    bounds.left * scaleX,
    bounds.top * scaleY,
    (bounds.right + 1) * scaleX,
    (bounds.bottom + 1) * scaleY,
  );

  final area = (rect.width * rect.height) / (image.width * image.height);
  if (area < _minimumArea || area > _maximumArea) return null;

  return rect;
}

/// Nearest-neighbour sample of [image] into a [_gridSize]² grid, laid out
/// row-major as three components per cell: Cb, Cr, and brightness scaled by
/// [_lumaWeight].
List<double> _sampleGrid(img.Image image) {
  final cells = List<double>.filled(_gridSize * _gridSize * 3, 0);

  for (var row = 0; row < _gridSize; row++) {
    final y = (row * image.height ~/ _gridSize).clamp(0, image.height - 1);
    for (var col = 0; col < _gridSize; col++) {
      final x = (col * image.width ~/ _gridSize).clamp(0, image.width - 1);
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();

      // BT.601, the same conversion `frame_quality.dart` uses for live frames.
      final i = (row * _gridSize + col) * 3;
      cells[i] = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
      cells[i + 1] = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
      cells[i + 2] = (0.299 * r + 0.587 * g + 0.114 * b) * _lumaWeight;
    }
  }

  return cells;
}

/// Median of the border cells, component by component.
///
/// The median rather than the mean: a banana running off the edge of the
/// frame, or a shadow along one side, shifts a mean but not a median.
List<double> _estimateBackground(List<double> cells) {
  final margin = math.max(1, (_gridSize * _borderFraction).round());
  final blues = <double>[];
  final reds = <double>[];
  final lumas = <double>[];

  for (var row = 0; row < _gridSize; row++) {
    final rowIsBorder = row < margin || row >= _gridSize - margin;
    for (var col = 0; col < _gridSize; col++) {
      if (!rowIsBorder && col >= margin && col < _gridSize - margin) continue;
      final i = (row * _gridSize + col) * 3;
      blues.add(cells[i]);
      reds.add(cells[i + 1]);
      lumas.add(cells[i + 2]);
    }
  }

  return [_median(blues), _median(reds), _median(lumas)];
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  values.sort();
  return values[values.length ~/ 2];
}

List<bool> _differsFromBackground(List<double> cells, List<double> background) {
  final mask = List<bool>.filled(_gridSize * _gridSize, false);

  for (var cell = 0; cell < mask.length; cell++) {
    final i = cell * 3;
    final dcb = cells[i] - background[0];
    final dcr = cells[i + 1] - background[1];
    final dy = cells[i + 2] - background[2];
    mask[cell] =
        math.sqrt(dcb * dcb + dcr * dcr + dy * dy) > _backgroundDistance;
  }

  return mask;
}

/// Morphological opening: erode, then dilate.
///
/// Erosion strips every structure thinner than the kernel — fabric seams,
/// wood grain, the bright rim along a shadow — and dilation restores the
/// solid regions that survived to their original size. Without the pair,
/// a single line of texture can bridge the subject to the frame edge and
/// the resulting box covers the whole photo.
void _open(List<bool> mask) {
  final eroded = List<bool>.filled(mask.length, false);

  for (var row = 0; row < _gridSize; row++) {
    for (var col = 0; col < _gridSize; col++) {
      final cell = row * _gridSize + col;
      if (!mask[cell]) continue;
      if (_neighbourCount(mask, row, col) >= _erodeNeighbours) {
        eroded[cell] = true;
      }
    }
  }

  for (var row = 0; row < _gridSize; row++) {
    for (var col = 0; col < _gridSize; col++) {
      final cell = row * _gridSize + col;
      // Dilate back, but only into cells that differed from the background
      // to begin with, so the subject cannot grow past its own edge.
      mask[cell] =
          eroded[cell] || (mask[cell] && _neighbourCount(eroded, row, col) > 0);
    }
  }
}

int _neighbourCount(List<bool> mask, int row, int col) {
  var count = 0;
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      if (dx == 0 && dy == 0) continue;
      final ny = row + dy;
      final nx = col + dx;
      if (ny < 0 || ny >= _gridSize || nx < 0 || nx >= _gridSize) continue;
      if (mask[ny * _gridSize + nx]) count++;
    }
  }
  return count;
}

/// Bounds of the largest 4-connected region in [mask], in grid cells.
///
/// Largest region, not every set cell: a shadow in one corner or a second
/// object on the table would otherwise stretch the bounds across both.
_GridBounds? _largestRegionBounds(List<bool> mask) {
  final visited = List<bool>.filled(mask.length, false);
  _GridBounds? best;
  var bestSize = 0;

  for (var start = 0; start < mask.length; start++) {
    if (!mask[start] || visited[start]) continue;

    // Iterative flood fill — a grid this size would risk a deep recursion.
    var size = 0;
    var minRow = _gridSize, maxRow = 0, minCol = _gridSize, maxCol = 0;
    final stack = <int>[start];
    visited[start] = true;

    while (stack.isNotEmpty) {
      final cell = stack.removeLast();
      final row = cell ~/ _gridSize;
      final col = cell % _gridSize;
      size++;
      minRow = math.min(minRow, row);
      maxRow = math.max(maxRow, row);
      minCol = math.min(minCol, col);
      maxCol = math.max(maxCol, col);

      void visit(int nextRow, int nextCol) {
        if (nextRow < 0 ||
            nextRow >= _gridSize ||
            nextCol < 0 ||
            nextCol >= _gridSize) {
          return;
        }
        final next = nextRow * _gridSize + nextCol;
        if (!mask[next] || visited[next]) return;
        visited[next] = true;
        stack.add(next);
      }

      visit(row - 1, col);
      visit(row + 1, col);
      visit(row, col - 1);
      visit(row, col + 1);
    }

    if (size > bestSize) {
      bestSize = size;
      best = _GridBounds(minCol, minRow, maxCol, maxRow);
    }
  }

  return best;
}

class _GridBounds {
  const _GridBounds(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;
}

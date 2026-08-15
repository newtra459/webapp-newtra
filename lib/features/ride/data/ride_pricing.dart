/// Ride pricing calculator.
///
/// Payment collection structure:
///   0–10 min cancel → flat ₹50
///   10–60 min       → 100 % of base fare
///   61–65 min       → buffer (no extra charge)
///   65–90 min       → +50 % of base fare
///   90–95 min       → buffer (no extra charge)
///   95–120 min      → +100 % of base fare
///   Pattern repeats every 60 min after the first 60.
class RidePricing {
  RidePricing._();

  static const double _cancelFee = 50.0;     // flat cancel fee (≤10 min)
  static const double _baseFare  = 100.0;    // base fare for 10–60 min

  /// Calculate total ride charge from ride duration in **seconds**.
  /// Returns a [RideBill] with line-item breakdown.
  static RideBill calculate(int durationSeconds) {
    final mins = durationSeconds / 60.0;

    // ── Early cancel ────────────────────────────────────────────────
    if (mins <= 10) {
      final gst = _cancelFee * 0.18;
      return RideBill(
        durationMinutes: mins,
        baseFare: 0,
        extraCharge: 0,
        cancelFee: _cancelFee,
        subtotal: _cancelFee,
        gst: gst,
        total: _cancelFee + gst,
        label: 'Cancelled within 10 min',
      );
    }

    // ── Base period (10–60 min) ─────────────────────────────────────
    double total = _baseFare;
    double extra = 0;
    String label = 'Base fare (10–60 min)';

    if (mins <= 60) {
      final gst = total * 0.18;
      return RideBill(
        durationMinutes: mins,
        baseFare: _baseFare,
        extraCharge: 0,
        cancelFee: 0,
        subtotal: total,
        gst: gst,
        total: total + gst,
        label: label,
      );
    }

    // ── Extended time (>60 min) ─────────────────────────────────────
    // Pattern per 60-min block after the first 60:
    //   0–5 min  → buffer (free)
    //   5–30 min → 50 % of base
    //   30–35    → buffer (free)
    //   35–60    → 100 % of base
    double overtime = mins - 60;

    while (overtime > 0) {
      if (overtime <= 5) {
        // buffer
        break;
      } else if (overtime <= 30) {
        extra += _baseFare * 0.5;
        break;
      } else if (overtime <= 35) {
        extra += _baseFare * 0.5;
        break;
      } else if (overtime <= 60) {
        extra += _baseFare * 0.5 + _baseFare;
        break;
      } else {
        // full 60-min extension block
        extra += _baseFare * 0.5 + _baseFare;
        overtime -= 60;
      }
    }

    total += extra;
    label = extra > 0 ? 'Base + overtime charges' : 'Base fare (buffer period)';

    final gst = total * 0.18;
    return RideBill(
      durationMinutes: mins,
      baseFare: _baseFare,
      extraCharge: extra,
      cancelFee: 0,
      subtotal: total,
      gst: gst,
      total: total + gst,
      label: label,
    );
  }
}

class RideBill {
  final double durationMinutes;
  final double baseFare;
  final double extraCharge;
  final double cancelFee;
  final double subtotal;
  final double gst;          // 18% of subtotal
  final double total;        // subtotal + gst
  final String label;

  const RideBill({
    required this.durationMinutes,
    required this.baseFare,
    required this.extraCharge,
    required this.cancelFee,
    required this.subtotal,
    required this.gst,
    required this.total,
    required this.label,
  });

  bool get isCancelled => cancelFee > 0;
  bool get hasOvertime => extraCharge > 0;

  String get formattedTotal => '₹${total.toStringAsFixed(2)}';

  String get durationDisplay {
    final totalMins = durationMinutes.round();
    if (totalMins < 60) return '$totalMins min';
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}

val score : Buffer.t -> float
(** [score buffer] is the mean absolute luminance difference between adjacent
    pixels, taken over every horizontally adjacent pair and every vertically
    adjacent pair. The result is on the same 0 to 255 scale as the luminance it
    is built from, and a higher score means a sharper image.

    Both axes are summed into one total because a single-axis metric is
    orientation-sensitive. Text and printed strokes run largely horizontally, so
    they produce mostly vertical brightness gradients; a metric reading only
    horizontal neighbours would score the same subject far lower merely for the
    way the camera was held. Summing both axes removes that dependence: turning
    a buffer through a quarter turn leaves the score unchanged, give or take the
    last bits of floating-point summation, since a quarter turn exchanges the
    horizontally and vertically adjacent pairs without altering the differences
    between them or how many there are.

    Dividing by the number of pairs rather than reporting the sum keeps scores
    from two buffers comparable when their dimensions differ: a sum grows with
    the pixel count on its own, a mean does not.

    Resampling is a separate matter and the normalization does not cover it.
    Scaling an image down does not merely change how many pairs there are, it
    changes the pixel values themselves, and detail that spanned several pixels
    is compressed into fewer and steeper differences. A capture measured at one
    long edge and the same capture measured at another will not score the same.
    Compare only scores measured at the same edge.

    The score measures contrast, not focus alone. Brightness differences shrink
    as a scene gets darker or flatter, so the same subject at the same focus
    scores lower in dim light than in bright light. Two scores are comparable
    only under comparable lighting.

    There is no built-in notion of a good enough score, and none is offered. The
    number carries no calibrated meaning on its own; deciding which scores pass
    is the consuming application's own calibration, made against its own
    subject, camera and lighting.

    A buffer holding a single pixel has no adjacent pair and scores [0.0], which
    reads as maximally blurry. Every other buffer has at least one pair, so a
    one-pixel-wide or one-pixel-tall strip is measured along its long axis
    rather than treated as degenerate. *)

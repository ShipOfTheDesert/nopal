val of_channels : r:int -> g:int -> b:int -> float
(** [of_channels ~r ~g ~b] is the perceptual luminance of one pixel, weighting
    the channels 0.299 red, 0.587 green and 0.114 blue. Each channel is a value
    from 0 to 255 and the result is on that same scale, so a gray pixel maps to
    its own channel value.

    Those are the standard perceptual weights, the same ones the JPEG pipeline
    encodes with. They are deliberately unequal: the eye draws most of its sense
    of brightness from green and very little from blue. Averaging the three
    channels instead would give blue about five times the weight it is seen
    with, so a blue edge would register as a far larger brightness change than
    it looks, and a green one as a smaller change than it looks. Anything
    measuring brightness contrast has to weight the channels the way they are
    perceived or it measures something the viewer does not see. *)

val of_buffer : Buffer.t -> float array
(** [of_buffer buffer] is the luminance of every pixel, in row-major order: left
    to right within a row, then top to bottom. The array holds one entry per
    pixel. The alpha channel takes no part in the conversion. *)

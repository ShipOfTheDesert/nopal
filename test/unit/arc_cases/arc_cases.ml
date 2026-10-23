type expected = Invalid | Sweep of float

type row = {
  name : string;
  direction : Nopal_scene.Path.direction;
  cx : float;
  cy : float;
  r : float;
  start_angle : float;
  end_angle : float;
  expected : expected;
}

let pi = Float.pi
let cx = 50.
let cy = 40.
let r = 30.

let rows : row list =
  let open Nopal_scene.Path in
  [
    {
      name = "increasing clockwise";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = 0.;
      end_angle = pi /. 2.;
      expected = Sweep (pi /. 2.);
    };
    {
      name = "increasing anticlockwise";
      direction = Anticlockwise;
      cx;
      cy;
      r;
      start_angle = 0.;
      end_angle = pi /. 2.;
      expected = Sweep (-3. *. pi /. 2.);
    };
    {
      name = "decreasing clockwise";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = pi;
      end_angle = pi /. 2.;
      expected = Sweep (3. *. pi /. 2.);
    };
    {
      name = "decreasing anticlockwise";
      direction = Anticlockwise;
      cx;
      cy;
      r;
      start_angle = pi;
      end_angle = pi /. 2.;
      expected = Sweep (-.pi /. 2.);
    };
    {
      name = "decreasing across zero clockwise";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = pi /. 4.;
      end_angle = -.pi /. 4.;
      expected = Sweep (3. *. pi /. 2.);
    };
    {
      name = "equal angles clockwise";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = 1.;
      end_angle = 1.;
      expected = Sweep 0.;
    };
    {
      name = "equal angles anticlockwise";
      direction = Anticlockwise;
      cx;
      cy;
      r;
      start_angle = 1.;
      end_angle = 1.;
      expected = Sweep 0.;
    };
    {
      name = "full turn increasing clockwise";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = 0.;
      end_angle = 2. *. pi;
      expected = Sweep (2. *. pi);
    };
    {
      name = "full turn decreasing anticlockwise";
      direction = Anticlockwise;
      cx;
      cy;
      r;
      start_angle = 2. *. pi;
      end_angle = 0.;
      expected = Sweep (-2. *. pi);
    };
    {
      name = "over a full turn clockwise";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = 0.;
      end_angle = 3. *. pi;
      expected = Sweep (2. *. pi);
    };
    {
      name = "over a full turn anticlockwise";
      direction = Anticlockwise;
      cx;
      cy;
      r;
      start_angle = 3. *. pi;
      end_angle = 0.;
      expected = Sweep (-2. *. pi);
    };
    {
      name = "whole turn down clockwise";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = 2. *. pi;
      end_angle = 0.;
      expected = Sweep 0.;
    };
    {
      name = "whole turn up anticlockwise";
      direction = Anticlockwise;
      cx;
      cy;
      r;
      start_angle = 0.;
      end_angle = 2. *. pi;
      expected = Sweep 0.;
    };
    {
      name = "zero radius";
      direction = Clockwise;
      cx;
      cy;
      r = 0.;
      start_angle = 0.;
      end_angle = pi /. 2.;
      expected = Sweep (pi /. 2.);
    };
    {
      name = "negative radius";
      direction = Clockwise;
      cx;
      cy;
      r = -1.;
      start_angle = 0.;
      end_angle = pi /. 2.;
      expected = Invalid;
    };
    {
      name = "nan start angle";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = Float.nan;
      end_angle = 1.;
      expected = Invalid;
    };
    {
      name = "infinite start angle";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = Float.infinity;
      end_angle = 1.;
      expected = Invalid;
    };
    {
      name = "nan end angle";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = 0.;
      end_angle = Float.nan;
      expected = Invalid;
    };
    {
      name = "infinite end angle";
      direction = Anticlockwise;
      cx;
      cy;
      r;
      start_angle = 0.;
      end_angle = Float.neg_infinity;
      expected = Invalid;
    };
    {
      name = "nan radius";
      direction = Clockwise;
      cx;
      cy;
      r = Float.nan;
      start_angle = 0.;
      end_angle = 1.;
      expected = Invalid;
    };
    {
      name = "infinite radius";
      direction = Clockwise;
      cx;
      cy;
      r = Float.infinity;
      start_angle = 0.;
      end_angle = 1.;
      expected = Invalid;
    };
    {
      name = "nan cx";
      direction = Clockwise;
      cx = Float.nan;
      cy;
      r;
      start_angle = 0.;
      end_angle = 1.;
      expected = Invalid;
    };
    {
      name = "infinite cx";
      direction = Clockwise;
      cx = Float.infinity;
      cy;
      r;
      start_angle = 0.;
      end_angle = 1.;
      expected = Invalid;
    };
    {
      name = "nan cy";
      direction = Clockwise;
      cx;
      cy = Float.nan;
      r;
      start_angle = 0.;
      end_angle = 1.;
      expected = Invalid;
    };
    {
      name = "infinite cy";
      direction = Clockwise;
      cx;
      cy = Float.neg_infinity;
      r;
      start_angle = 0.;
      end_angle = 1.;
      expected = Invalid;
    };
    {
      name = "huge angles keep their sweep";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = 1e17;
      end_angle = 1e17 +. 16.;
      expected = Sweep (2. *. pi);
    };
    {
      name = "decreasing across zero anticlockwise";
      direction = Anticlockwise;
      cx;
      cy;
      r;
      start_angle = pi /. 4.;
      end_angle = -.pi /. 4.;
      expected = Sweep (-.pi /. 2.);
    };
    {
      name = "huge angles keep their sweep anticlockwise";
      direction = Anticlockwise;
      cx;
      cy;
      r;
      start_angle = 1e17 +. 16.;
      end_angle = 1e17;
      expected = Sweep (-2. *. pi);
    };
    {
      name = "full turn with a non-zero start clockwise";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = 0.1;
      end_angle = 0.1 +. (2. *. pi);
      expected = Sweep (2. *. pi);
    };
    {
      name = "tiny negative start clockwise";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = -1e-17;
      end_angle = pi /. 2.;
      expected = Sweep (pi /. 2.);
    };
    {
      name = "subnormal sweep";
      direction = Clockwise;
      cx;
      cy;
      r;
      start_angle = 0.;
      end_angle = 5e-324;
      expected = Sweep 0.;
    };
  ]

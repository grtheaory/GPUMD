/*
    Copyright 2017 Zheyong Fan, Ville Vierimaa, Mikko Ervasti, and Ari Harju
    This file is part of GPUMD.
    GPUMD is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    GPUMD is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with GPUMD.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma once

const int NUM_OF_ABC = 24; // 3 + 5 + 7 + 9 for L_max = 4
__constant__ float YLM[NUM_OF_ABC] = {
  0.238732414637843f, 0.119366207318922f, 0.119366207318922f, 0.099471839432435f,
  0.596831036594608f, 0.596831036594608f, 0.149207759148652f, 0.149207759148652f,
  0.139260575205408f, 0.104445431404056f, 0.104445431404056f, 1.044454314040563f,
  1.044454314040563f, 0.174075719006761f, 0.174075719006761f, 0.011190581936149f,
  0.223811638722978f, 0.223811638722978f, 0.111905819361489f, 0.111905819361489f,
  1.566681471060845f, 1.566681471060845f, 0.195835183882606f, 0.195835183882606f};

const int SIZE_BOX_AND_INVERSE_BOX = 18;  // (3 * 3) * 2
const int MAX_NUM_NEURONS_PER_LAYER = 50; // largest ANN: input-50-50-output
const int MAX_NUM_N = 20;                 // n_max+1 = 19+1
const int MAX_NUM_L = 5;                  // L_max+1 = 4+1
const int MAX_DIM = MAX_NUM_N * MAX_NUM_L;
const int MAX_DIM_ANGULAR = MAX_NUM_N * (MAX_NUM_L - 1);
__constant__ float c_parameters[14201]; // (100+2)*100+1+40*100, less than 64 KB maximum

static __device__ __forceinline__ void find_fc(float rc, float rcinv, float d12, float& fc)
{
  if (d12 < rc) {
    float x = d12 * rcinv;
    fc = 0.5f * cos(3.1415927f * x) + 0.5f;
  } else {
    fc = 0.0f;
  }
}

static __device__ __forceinline__ void
find_fc_and_fcp(float rc, float rcinv, float d12, float& fc, float& fcp)
{
  if (d12 < rc) {
    float x = d12 * rcinv;
    fc = 0.5f * cos(3.1415927f * x) + 0.5f;
    fcp = -1.5707963f * sin(3.1415927f * x);
    fcp *= rcinv;
  } else {
    fc = 0.0f;
    fcp = 0.0f;
  }
}

#ifdef USE_ZBL  
static __device__ __forceinline__ void
find_fc_and_fcp_zbl(float r1, float r2, float d12, float& fc, float& fcp)
{
  float chi = (d12 - r1) / (r2 - r1);
  float chip = 1 / (r2 - r1);
  float chi2 = chi * chi;
  if (d12 < r1) {
    fc = 1;
    fcp = 0;
  } else if (d12 < r2) {
    fc = 1 - chi * chi2 * (6 * chi2 -15 * chi + 10);
    fcp = -chip * (3 * chi2 * (6 * chi2 -15 * chi + 10) + chi * chi2 * (12 * chi - 15));
  } else {
    fc = 0;
    fcp = 0;	  
  }
}
#endif

static __device__ __forceinline__ void
find_fn(const int n, const float rcinv, const float d12, const float fc12, float& fn)
{
  if (n == 0) {
    fn = fc12;
  } else if (n == 1) {
    float x = 2.0f * (d12 * rcinv - 1.0f) * (d12 * rcinv - 1.0f) - 1.0f;
    fn = (x + 1.0f) * 0.5f * fc12;
  } else {
    float x = 2.0f * (d12 * rcinv - 1.0f) * (d12 * rcinv - 1.0f) - 1.0f;
    float t0 = 1.0f;
    float t1 = x;
    float t2;
    for (int m = 2; m <= n; ++m) {
      t2 = 2.0f * x * t1 - t0;
      t0 = t1;
      t1 = t2;
    }
    fn = (t2 + 1.0f) * 0.5f * fc12;
  }
}

static __device__ __forceinline__ void find_fn_and_fnp(
  const int n,
  const float rcinv,
  const float d12,
  const float fc12,
  const float fcp12,
  float& fn,
  float& fnp)
{
  if (n == 0) {
    fn = fc12;
    fnp = fcp12;
  } else if (n == 1) {
    float x = 2.0f * (d12 * rcinv - 1.0f) * (d12 * rcinv - 1.0f) - 1.0f;
    fn = (x + 1.0f) * 0.5f;
    fnp = 2.0f * (d12 * rcinv - 1.0f) * rcinv * fc12 + fn * fcp12;
    fn *= fc12;
  } else {
    float x = 2.0f * (d12 * rcinv - 1.0f) * (d12 * rcinv - 1.0f) - 1.0f;
    float t0 = 1.0f;
    float t1 = x;
    float t2;
    float u0 = 1.0f;
    float u1 = 2.0f * x;
    float u2;
    for (int m = 2; m <= n; ++m) {
      t2 = 2.0f * x * t1 - t0;
      t0 = t1;
      t1 = t2;
      u2 = 2.0f * x * u1 - u0;
      u0 = u1;
      u1 = u2;
    }
    fn = (t2 + 1.0f) * 0.5f;
    fnp = n * u0 * 2.0f * (d12 * rcinv - 1.0f) * rcinv;
    fnp = fnp * fc12 + fn * fcp12;
    fn *= fc12;
  }
}

static __device__ __forceinline__ void
find_fn(const int n_max, const float rcinv, const float d12, const float fc12, float* fn)
{
  float x = 2.0f * (d12 * rcinv - 1.0f) * (d12 * rcinv - 1.0f) - 1.0f;
  fn[0] = 1.0f;
  fn[1] = x;
  for (int m = 2; m <= n_max; ++m) {
    fn[m] = 2.0f * x * fn[m - 1] - fn[m - 2];
  }
  for (int m = 0; m <= n_max; ++m) {
    fn[m] = (fn[m] + 1.0f) * 0.5f * fc12;
  }
}

static __device__ __forceinline__ void find_fn_and_fnp(
  const int n_max,
  const float rcinv,
  const float d12,
  const float fc12,
  const float fcp12,
  float* fn,
  float* fnp)
{
  float x = 2.0f * (d12 * rcinv - 1.0f) * (d12 * rcinv - 1.0f) - 1.0f;
  fn[0] = 1.0f;
  fnp[0] = 0.0f;
  fn[1] = x;
  fnp[1] = 1.0f;
  float u0 = 1.0f;
  float u1 = 2.0f * x;
  float u2;
  for (int m = 2; m <= n_max; ++m) {
    fn[m] = 2.0f * x * fn[m - 1] - fn[m - 2];
    fnp[m] = m * u1;
    u2 = 2.0f * x * u1 - u0;
    u0 = u1;
    u1 = u2;
  }
  for (int m = 0; m <= n_max; ++m) {
    fn[m] = (fn[m] + 1.0f) * 0.5f;
    fnp[m] *= 2.0f * (d12 * rcinv - 1.0f) * rcinv;
    fnp[m] = fnp[m] * fc12 + fn[m] * fcp12;
    fn[m] *= fc12;
  }
}

static __device__ __forceinline__ void
find_poly_cos(const int L_max, const float x, float* poly_cos)
{
  poly_cos[0] = 0.079577471545948f;
  poly_cos[1] = 0.238732414637843f * x;
  float x2 = x * x;
  poly_cos[2] = 0.596831036594608f * x2 - 0.198943678864869f;
  float x3 = x2 * x;
  poly_cos[3] = 1.392605752054084f * x3 - 0.835563451232451f * x;
  float x4 = x3 * x;
  poly_cos[4] = 3.133362942121690f * x4 - 2.685739664675734f * x2 + 0.268573966467573f;
  float x5 = x4 * x;
  poly_cos[5] = 6.893398472667717f * x5 - 7.659331636297464f * x3 + 1.641285350635171f * x;
  float x6 = x5 * x;
  poly_cos[6] = 14.935696690780054f * x6 - 20.366859123790981f * x4 + 6.788953041263660f * x2 -
                0.323283478155412f;
}

static __device__ __forceinline__ void
find_poly_cos_and_der(const int L_max, const float x, float* poly_cos, float* poly_cos_der)
{
  poly_cos[0] = 0.079577471545948f;
  poly_cos[1] = 0.238732414637843f * x;
  poly_cos_der[0] = 0.0f;
  poly_cos_der[1] = 0.238732414637843f;
  poly_cos_der[2] = 1.193662073189215f * x;
  float x2 = x * x;
  poly_cos[2] = 0.596831036594608f * x2 - 0.198943678864869f;
  poly_cos_der[3] = 4.177817256162252f * x2 - 0.835563451232451f;
  float x3 = x2 * x;
  poly_cos[3] = 1.392605752054084f * x3 - 0.835563451232451f * x;
  poly_cos_der[4] = 12.533451768486758f * x3 - 5.371479329351468f * x;
  float x4 = x3 * x;
  poly_cos[4] = 3.133362942121690f * x4 - 2.685739664675734f * x2 + 0.268573966467573f;
  poly_cos_der[5] = 34.466992363338584f * x4 - 22.977994908892391f * x2 + 1.641285350635171f;
  float x5 = x4 * x;
  poly_cos[5] = 6.893398472667717f * x5 - 7.659331636297464f * x3 + 1.641285350635171f * x;
  poly_cos_der[6] = 89.614180144680319f * x5 - 81.467436495163923f * x3 + 13.577906082527321f * x;
  float x6 = x5 * x;
  poly_cos[6] = 14.935696690780054f * x6 - 20.366859123790981f * x4 + 6.788953041263660f * x2 -
                0.323283478155412f;
}

static __device__ __forceinline__ void get_f12_1(
  const float d12inv,
  const float fn,
  const float fnp,
  const float Fp,
  const float* s,
  const float* r12,
  float* f12)
{
  float tmp = s[1] * r12[0];
  tmp += s[2] * r12[1];
  tmp *= 2.0f;
  tmp += s[0] * r12[2];
  tmp *= Fp * fnp * d12inv;
  for (int d = 0; d < 3; ++d) {
    f12[d] += tmp * r12[d];
  }
  tmp = Fp * fn;
  f12[0] += tmp * 2.0f * s[1];
  f12[1] += tmp * 2.0f * s[2];
  f12[2] += tmp * s[0];
}

static __device__ __forceinline__ void get_f12_2(
  const float d12,
  const float d12inv,
  const float fn,
  const float fnp,
  const float Fp,
  const float* s,
  const float* r12,
  float* f12)
{
  float tmp = s[1] * r12[0] * r12[2];                // Re[Y21]
  tmp += s[2] * r12[1] * r12[2];                     // Im[Y21]
  tmp += s[3] * (r12[0] * r12[0] - r12[1] * r12[1]); // Re[Y22]
  tmp += s[4] * 2.0f * r12[0] * r12[1];              // Im[Y22]
  tmp *= 2.0f;
  tmp += s[0] * (3.0f * r12[2] * r12[2] - d12 * d12); // Y20
  tmp *= Fp * fnp * d12inv;
  for (int d = 0; d < 3; ++d) {
    f12[d] += tmp * r12[d];
  }
  tmp = Fp * fn * 2.0f;
  f12[0] += tmp * (-s[0] * r12[0] + s[1] * r12[2] + 2.0f * s[3] * r12[0] + 2.0f * s[4] * r12[1]);
  f12[1] += tmp * (-s[0] * r12[1] + s[2] * r12[2] - 2.0f * s[3] * r12[1] + 2.0f * s[4] * r12[0]);
  f12[2] += tmp * (2.0f * s[0] * r12[2] + s[1] * r12[0] + s[2] * r12[1]);
}

static __device__ __forceinline__ void get_f12_3(
  const float d12,
  const float d12inv,
  const float fn,
  const float fnp,
  const float Fp,
  const float* s,
  const float* r12,
  float* f12)
{
  float d12sq = d12 * d12;
  float x2 = r12[0] * r12[0];
  float y2 = r12[1] * r12[1];
  float z2 = r12[2] * r12[2];
  float xy = r12[0] * r12[1];
  float xz = r12[0] * r12[2];
  float yz = r12[1] * r12[2];

  float tmp = s[1] * (5.0f * z2 - d12sq) * r12[0];
  tmp += s[2] * (5.0f * z2 - d12sq) * r12[1];
  tmp += s[3] * (x2 - y2) * r12[2];
  tmp += s[4] * 2.0f * xy * r12[2];
  tmp += s[5] * r12[0] * (x2 - 3.0f * y2);
  tmp += s[6] * r12[1] * (3.0f * x2 - y2);
  tmp *= 2.0f;
  tmp += s[0] * (5.0f * z2 - 3.0f * d12sq) * r12[2];
  tmp *= Fp * fnp * d12inv;
  for (int d = 0; d < 3; ++d) {
    f12[d] += tmp * r12[d];
  }

  // x
  tmp = s[1] * (4.0f * z2 - 3.0f * x2 - y2);
  tmp += s[2] * (-2.0f * xy);
  tmp += s[3] * 2.0f * xz;
  tmp += s[4] * (2.0f * yz);
  tmp += s[5] * (3.0f * (x2 - y2));
  tmp += s[6] * (6.0f * xy);
  tmp *= 2.0f;
  tmp += s[0] * (-6.0f * xz);
  f12[0] += tmp * Fp * fn;
  // y
  tmp = s[1] * (-2.0f * xy);
  tmp += s[2] * (4.0f * z2 - 3.0f * y2 - x2);
  tmp += s[3] * (-2.0f * yz);
  tmp += s[4] * (2.0f * xz);
  tmp += s[5] * (-6.0f * xy);
  tmp += s[6] * (3.0f * (x2 - y2));
  tmp *= 2.0f;
  tmp += s[0] * (-6.0f * yz);
  f12[1] += tmp * Fp * fn;
  // z
  tmp = s[1] * (8.0f * xz);
  tmp += s[2] * (8.0f * yz);
  tmp += s[3] * (x2 - y2);
  tmp += s[4] * (2.0f * xy);
  tmp *= 2.0f;
  tmp += s[0] * (9.0f * z2 - 3.0f * d12sq);
  f12[2] += tmp * Fp * fn;
}

static __device__ __forceinline__ void get_f12_4(
  const float x,
  const float y,
  const float z,
  const float r,
  const float rinv,
  const float fn,
  const float fnp,
  const float Fp,
  const float* s,
  float* f12)
{
  const float r2 = r * r;
  const float x2 = x * x;
  const float y2 = y * y;
  const float z2 = z * z;
  const float xy = x * y;
  const float xz = x * z;
  const float yz = y * z;
  const float xyz = x * yz;
  const float x2my2 = x2 - y2;

  float tmp = s[1] * (7.0f * z2 - 3.0f * r2) * xz; // Y41_real
  tmp += s[2] * (7.0f * z2 - 3.0f * r2) * yz;      // Y41_imag
  tmp += s[3] * (7.0f * z2 - r2) * x2my2;          // Y42_real
  tmp += s[4] * (7.0f * z2 - r2) * 2.0f * xy;      // Y42_imag
  tmp += s[5] * (x2 - 3.0f * y2) * xz;             // Y43_real
  tmp += s[6] * (3.0f * x2 - y2) * yz;             // Y43_imag
  tmp += s[7] * (x2my2 * x2my2 - 4.0f * x2 * y2);  // Y44_real
  tmp += s[8] * (4.0f * xy * x2my2);               // Y44_imag
  tmp *= 2.0f;
  tmp += s[0] * ((35.0f * z2 - 30.0f * r2) * z2 + 3.0f * r2 * r2); // Y40
  tmp *= Fp * fnp * rinv;
  f12[0] += tmp * x;
  f12[1] += tmp * y;
  f12[2] += tmp * z;

  // x
  tmp = s[1] * z * (7.0f * z2 - 3.0f * r2 - 6.0f * x2);  // Y41_real
  tmp += s[2] * (-6.0f * xyz);                           // Y41_imag
  tmp += s[3] * 4.0f * x * (3.0f * z2 - x2);             // Y42_real
  tmp += s[4] * 2.0f * y * (7.0f * z2 - r2 - 2.0f * x2); // Y42_imag
  tmp += s[5] * 3.0f * z * x2my2;                        // Y43_real
  tmp += s[6] * 6.0f * xyz;                              // Y43_imag
  tmp += s[7] * 4.0f * x * (x2 - 3.0f * y2);             // Y44_real
  tmp += s[8] * 4.0f * y * (3.0f * x2 - y2);             // Y44_imag
  tmp *= 2.0f;
  tmp += s[0] * 12.0f * x * (r2 - 5.0f * z2); // Y40
  f12[0] += tmp * Fp * fn;
  // y
  tmp = s[1] * (-6.0f * xyz);                            // Y41_real
  tmp += s[2] * z * (7.0f * z2 - 3.0f * r2 - 6.0f * y2); // Y41_imag
  tmp += s[3] * 4.0f * y * (y2 - 3.0f * z2);             // Y42_real
  tmp += s[4] * 2.0f * x * (7.0f * z2 - r2 - 2.0f * y2); // Y42_imag
  tmp += s[5] * (-6.0f * xyz);                           // Y43_real
  tmp += s[6] * 3.0f * z * x2my2;                        // Y43_imag
  tmp += s[7] * 4.0f * y * (y2 - 3.0f * x2);             // Y44_real
  tmp += s[8] * 4.0f * x * (x2 - 3.0f * y2);             // Y44_imag
  tmp *= 2.0f;
  tmp += s[0] * 12.0f * y * (r2 - 5.0f * z2); // Y40
  f12[1] += tmp * Fp * fn;
  // z
  tmp = s[1] * 3.0f * x * (5.0f * z2 - r2);  // Y41_real
  tmp += s[2] * 3.0f * y * (5.0f * z2 - r2); // Y41_imag
  tmp += s[3] * 12.0f * z * x2my2;           // Y42_real
  tmp += s[4] * 24.0f * xyz;                 // Y42_imag
  tmp += s[5] * x * (x2 - 3.0f * y2);        // Y43_real
  tmp += s[6] * y * (3.0f * x2 - y2);        // Y43_imag
  tmp *= 2.0f;
  tmp += s[0] * 16.0f * z * (5.0f * z2 - 3.0f * r2); // Y40
  f12[2] += tmp * Fp * fn;
}

static __device__ __forceinline__ void accumulate_f12(
  const int n,
  const int n1,
  const int n_max_radial_plus_1,
  const int n_max_angular_plus_1,
  const float d12,
  const float* r12,
  float fn,
  float fnp,
  const float* Fp,
  const float* sum_fxyz,
  float* f12)
{
  const float d12inv = 1.0f / d12;
  // l = 1
  fnp = fnp * d12inv - fn * d12inv * d12inv;
  fn = fn * d12inv;
  float s1[3] = {
    sum_fxyz[n * NUM_OF_ABC + 0], sum_fxyz[n * NUM_OF_ABC + 1], sum_fxyz[n * NUM_OF_ABC + 2]};
  get_f12_1(d12inv, fn, fnp, Fp[n], s1, r12, f12);
  // l = 2
  fnp = fnp * d12inv - fn * d12inv * d12inv;
  fn = fn * d12inv;
  float s2[5] = {
    sum_fxyz[n * NUM_OF_ABC + 3], sum_fxyz[n * NUM_OF_ABC + 4], sum_fxyz[n * NUM_OF_ABC + 5],
    sum_fxyz[n * NUM_OF_ABC + 6], sum_fxyz[n * NUM_OF_ABC + 7]};
  get_f12_2(d12, d12inv, fn, fnp, Fp[n_max_angular_plus_1 + n], s2, r12, f12);
  // l = 3
  fnp = fnp * d12inv - fn * d12inv * d12inv;
  fn = fn * d12inv;
  float s3[7] = {sum_fxyz[n * NUM_OF_ABC + 8],  sum_fxyz[n * NUM_OF_ABC + 9],
                 sum_fxyz[n * NUM_OF_ABC + 10], sum_fxyz[n * NUM_OF_ABC + 11],
                 sum_fxyz[n * NUM_OF_ABC + 12], sum_fxyz[n * NUM_OF_ABC + 13],
                 sum_fxyz[n * NUM_OF_ABC + 14]};
  get_f12_3(d12, d12inv, fn, fnp, Fp[2 * n_max_angular_plus_1 + n], s3, r12, f12);
  // l = 4
  fnp = fnp * d12inv - fn * d12inv * d12inv;
  fn = fn * d12inv;
  float s4[9] = {
    sum_fxyz[n * NUM_OF_ABC + 15], sum_fxyz[n * NUM_OF_ABC + 16], sum_fxyz[n * NUM_OF_ABC + 17],
    sum_fxyz[n * NUM_OF_ABC + 18], sum_fxyz[n * NUM_OF_ABC + 19], sum_fxyz[n * NUM_OF_ABC + 20],
    sum_fxyz[n * NUM_OF_ABC + 21], sum_fxyz[n * NUM_OF_ABC + 22], sum_fxyz[n * NUM_OF_ABC + 23]};
  get_f12_4(
    r12[0], r12[1], r12[2], d12, d12inv, fn, fnp, Fp[3 * n_max_angular_plus_1 + n], s4, f12);
}

static __device__ __forceinline__ void find_f12(
  const int n1,
  const int n_max_radial,
  const int n_max_angular,
  const float rcinv_angular,
  const float d12,
  const float fc12,
  const float fcp12,
  const float* r12,
  const float* Fp,
  const float* sum_fxyz,
  float* f12)
{
  for (int n = 0; n <= n_max_angular; ++n) {
    float fn;
    float fnp;
    find_fn_and_fnp(n, rcinv_angular, d12, fc12, fcp12, fn, fnp);
    accumulate_f12(
      n, n1, n_max_radial + 1, n_max_angular + 1, d12, r12, fn, fnp, Fp, sum_fxyz, f12);
  }
}

static __device__ __forceinline__ void
accumulate_s(const float d12, float x12, float y12, float z12, const float fn, float* s)
{
  float d12inv = 1.0f / d12;
  x12 *= d12inv;
  y12 *= d12inv;
  z12 *= d12inv;
  float x12sq = x12 * x12;
  float y12sq = y12 * y12;
  float z12sq = z12 * z12;
  float x12sq_minus_y12sq = x12sq - y12sq;
  s[0] += z12 * fn;                                                             // Y10
  s[1] += x12 * fn;                                                             // Y11_real
  s[2] += y12 * fn;                                                             // Y11_imag
  s[3] += (3.0f * z12sq - 1.0f) * fn;                                           // Y20
  s[4] += x12 * z12 * fn;                                                       // Y21_real
  s[5] += y12 * z12 * fn;                                                       // Y21_imag
  s[6] += x12sq_minus_y12sq * fn;                                               // Y22_real
  s[7] += 2.0f * x12 * y12 * fn;                                                // Y22_imag
  s[8] += (5.0f * z12sq - 3.0f) * z12 * fn;                                     // Y30
  s[9] += (5.0f * z12sq - 1.0f) * x12 * fn;                                     // Y31_real
  s[10] += (5.0f * z12sq - 1.0f) * y12 * fn;                                    // Y31_imag
  s[11] += x12sq_minus_y12sq * z12 * fn;                                        // Y32_real
  s[12] += 2.0f * x12 * y12 * z12 * fn;                                         // Y32_imag
  s[13] += (x12 * x12 - 3.0f * y12 * y12) * x12 * fn;                           // Y33_real
  s[14] += (3.0f * x12 * x12 - y12 * y12) * y12 * fn;                           // Y33_imag
  s[15] += ((35.0f * z12sq - 30.0f) * z12sq + 3.0f) * fn;                       // Y40
  s[16] += (7.0f * z12sq - 3.0f) * x12 * z12 * fn;                              // Y41_real
  s[17] += (7.0f * z12sq - 3.0f) * y12 * z12 * fn;                              // Y41_iamg
  s[18] += (7.0f * z12sq - 1.0f) * x12sq_minus_y12sq * fn;                      // Y42_real
  s[19] += (7.0f * z12sq - 1.0f) * x12 * y12 * 2.0f * fn;                       // Y42_imag
  s[20] += (x12sq - 3.0f * y12sq) * x12 * z12 * fn;                             // Y43_real
  s[21] += (3.0f * x12sq - y12sq) * y12 * z12 * fn;                             // Y43_imag
  s[22] += (x12sq_minus_y12sq * x12sq_minus_y12sq - 4.0f * x12sq * y12sq) * fn; // Y44_real
  s[23] += (4.0f * x12 * y12 * x12sq_minus_y12sq) * fn;                         // Y44_imag
}

static __device__ __forceinline__ void
find_q(const int n_max_angular_plus_1, const int n, const float* s, float* q)
{
  q[n] = YLM[0] * s[0] * s[0] + 2.0f * (YLM[1] * s[1] * s[1] + YLM[2] * s[2] * s[2]);
  q[n_max_angular_plus_1 + n] =
    YLM[3] * s[3] * s[3] + 2.0f * (YLM[4] * s[4] * s[4] + YLM[5] * s[5] * s[5] +
                                   YLM[6] * s[6] * s[6] + YLM[7] * s[7] * s[7]);
  q[2 * n_max_angular_plus_1 + n] =
    YLM[8] * s[8] * s[8] +
    2.0f * (YLM[9] * s[9] * s[9] + YLM[10] * s[10] * s[10] + YLM[11] * s[11] * s[11] +
            YLM[12] * s[12] * s[12] + YLM[13] * s[13] * s[13] + YLM[14] * s[14] * s[14]);
  q[3 * n_max_angular_plus_1 + n] =
    YLM[15] * s[15] * s[15] +
    2.0f * (YLM[16] * s[16] * s[16] + YLM[17] * s[17] * s[17] + YLM[18] * s[18] * s[18] +
            YLM[19] * s[19] * s[19] + YLM[20] * s[20] * s[20] + YLM[21] * s[21] * s[21] +
            YLM[22] * s[22] * s[22] + YLM[23] * s[23] * s[23]);
}

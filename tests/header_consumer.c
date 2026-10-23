#include "dim.h"

int main(void) {
  DimContext *ctx = dim_ctx_new();
  if (ctx == 0) return 1;

  const uint8_t input[] = "1 m";
  DimEvalResult result = {0};
  const int32_t status = dim_ctx_eval(ctx, input, sizeof(input) - 1, &result);
  if (status != DIM_STATUS_OK) return 1;
  const uint8_t scalar[] = "2";
  DimQuantityResult quantity = {0};
  const int32_t quantity_status = dim_ctx_eval_quantity(ctx, scalar, sizeof(scalar) - 1, &quantity);
  if (quantity_status != DIM_STATUS_OK || quantity.value != 2 ||
      quantity.dim_L_num != 0 || quantity.dim_L_den != 1 ||
      quantity.unit_len != 1 || ((const char *)quantity.unit_ptr)[0] != '1') return 1;
  dim_ffi_reset();
  dim_ctx_free(ctx);
  return status == DIM_STATUS_OK ? 0 : 1;
}

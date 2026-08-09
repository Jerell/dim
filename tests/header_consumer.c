#include "dim.h"

int main(void) {
  DimContext *ctx = dim_ctx_new();
  if (ctx == 0) return 1;

  const uint8_t input[] = "1 m";
  DimEvalResult result = {0};
  const int32_t status = dim_ctx_eval(ctx, input, sizeof(input) - 1, &result);
  dim_ffi_reset();
  dim_ctx_free(ctx);
  return status == DIM_STATUS_OK ? 0 : 1;
}

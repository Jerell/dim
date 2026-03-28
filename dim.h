#ifndef DIM_H
#define DIM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

  typedef struct DimContext DimContext;

  typedef enum DimStatus
  {
    DIM_STATUS_OK = 0,
    DIM_STATUS_EVAL_ERROR = 1,
    DIM_STATUS_INVALID_ARGUMENT = 2,
    DIM_STATUS_WRONG_KIND = 3,
    DIM_STATUS_OUT_OF_MEMORY = 4,
  } DimStatus;

  typedef enum DimValueKind
  {
    DIM_VALUE_NUMBER = 0,
    DIM_VALUE_BOOLEAN = 1,
    DIM_VALUE_STRING = 2,
    DIM_VALUE_QUANTITY = 3,
    DIM_VALUE_NIL = 4,
  } DimValueKind;

  typedef enum DimFormatMode
  {
    DIM_FORMAT_NONE = 0,
    DIM_FORMAT_AUTO = 1,
    DIM_FORMAT_SCIENTIFIC = 2,
    DIM_FORMAT_ENGINEERING = 3,
  } DimFormatMode;

  typedef struct DimSlice
  {
    uintptr_t ptr;
    size_t len;
  } DimSlice;

  typedef struct DimEvalResult
  {
    uint32_t kind;
    uint32_t bool_value;
    uint32_t mode;
    uint32_t is_delta;
    double number_value;
    double quantity_value;
    int32_t dim_L;
    int32_t dim_M;
    int32_t dim_T;
    int32_t dim_I;
    int32_t dim_Th;
    int32_t dim_N;
    int32_t dim_J;
    uintptr_t string_ptr;
    size_t string_len;
    uintptr_t unit_ptr;
    size_t unit_len;
  } DimEvalResult;

  typedef struct DimQuantityResult
  {
    uint32_t mode;
    uint32_t is_delta;
    double value;
    int32_t dim_L;
    int32_t dim_M;
    int32_t dim_T;
    int32_t dim_I;
    int32_t dim_Th;
    int32_t dim_N;
    int32_t dim_J;
    uintptr_t unit_ptr;
    size_t unit_len;
  } DimQuantityResult;

  DimContext *dim_ctx_new(void);
  void dim_ctx_free(DimContext *ctx);

  int32_t dim_ctx_define(
      DimContext *ctx,
      const uint8_t *name_ptr,
      size_t name_len,
      const uint8_t *expr_ptr,
      size_t expr_len);

  void dim_ctx_clear(DimContext *ctx, const uint8_t *name_ptr, size_t name_len);
  void dim_ctx_clear_all(DimContext *ctx);

  int32_t dim_ctx_eval(
      DimContext *ctx,
      const uint8_t *input_ptr,
      size_t input_len,
      DimEvalResult *out_result);

  int32_t dim_ctx_convert_expr(
      DimContext *ctx,
      const uint8_t *expr_ptr,
      size_t expr_len,
      const uint8_t *unit_ptr,
      size_t unit_len,
      DimQuantityResult *out_result);

  int32_t dim_ctx_convert_value(
      DimContext *ctx,
      double value,
      const uint8_t *from_ptr,
      size_t from_len,
      const uint8_t *to_ptr,
      size_t to_len,
      double *out_value);

  int32_t dim_ctx_is_compatible(
      DimContext *ctx,
      const uint8_t *expr_ptr,
      size_t expr_len,
      const uint8_t *unit_ptr,
      size_t unit_len,
      uint32_t *out_bool);

  int32_t dim_ctx_same_dimension(
      DimContext *ctx,
      const uint8_t *lhs_ptr,
      size_t lhs_len,
      const uint8_t *rhs_ptr,
      size_t rhs_len,
      uint32_t *out_bool);

  int32_t dim_ctx_batch_convert_exprs(
      DimContext *ctx,
      const DimSlice *exprs_ptr,
      const DimSlice *units_ptr,
      size_t count,
      double *out_values,
      uint32_t *out_statuses);

  int32_t dim_ctx_batch_convert_values(
      DimContext *ctx,
      const double *values_ptr,
      const DimSlice *from_units_ptr,
      const DimSlice *to_units_ptr,
      size_t count,
      double *out_values,
      uint32_t *out_statuses);

  void dim_free(uint8_t *ptr, size_t len);
  uint8_t *dim_alloc(size_t n);

#ifdef __cplusplus
}
#endif

#endif // DIM_H

#ifndef DIM_H
#define DIM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

  /**
   * Evaluate a dim expression string.
   *
   * @param input_ptr Pointer to the input string
   * @param input_len Length of the input string
   * @param out_ptr Output pointer to the result string (must be freed with dim_free)
   * @param out_len Output length of the result string
   * @return 0 on success, non-zero on failure
   */
  int32_t dim_eval(const uint8_t *input_ptr, size_t input_len, uint8_t **out_ptr, size_t *out_len);

  /**
   * Define a constant from an expression.
   *
   * @param name_ptr Pointer to the constant name
   * @param name_len Length of the constant name
   * @param expr_ptr Pointer to the expression string
   * @param expr_len Length of the expression string
   * @return 0 on success, non-zero on failure
   */
  int32_t dim_define(const uint8_t *name_ptr, size_t name_len, const uint8_t *expr_ptr, size_t expr_len);

  /**
   * Clear a specific constant by name.
   *
   * @param name_ptr Pointer to the constant name
   * @param name_len Length of the constant name
   */
  void dim_clear(const uint8_t *name_ptr, size_t name_len);

  /**
   * Clear all defined constants.
   */
  void dim_clear_all(void);

  /**
   * Free memory returned by dim_eval.
   *
   * @param ptr Pointer to the memory to free
   * @param len Length of the memory block
   */
  void dim_free(uint8_t *ptr, size_t len);

  /**
   * Allocate memory (for scratch space).
   *
   * @param n Number of bytes to allocate
   * @return Pointer to allocated memory, or NULL on failure
   */
  uint8_t *dim_alloc(size_t n);

#ifdef __cplusplus
}
#endif

#endif // DIM_H


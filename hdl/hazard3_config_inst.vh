// Pass-through of parameters defined in hazard3_config.vh, so that these can
// be set at instantiation rather than editing the config file, and will flow
// correctly down through the hierarchy.

.RESET_VECTOR    (RESET_VECTOR),
.MTVEC_INIT      (MTVEC_INIT),
.EXTENSION_C     (EXTENSION_C),
.EXTENSION_M     (EXTENSION_M),
.CSR_M_MANDATORY (CSR_M_MANDATORY),
.CSR_M_TRAP      (CSR_M_TRAP),
.CSR_COUNTER     (CSR_COUNTER),
.DEBUG_SUPPORT   (DEBUG_SUPPORT),
.NUM_IRQ         (NUM_IRQ),
.MVENDORID_VAL   (MVENDORID_VAL),
.MARCHID_VAL     (MARCHID_VAL),
.MIMPID_VAL      (MIMPID_VAL),
.MHARTID_VAL     (MHARTID_VAL),
.REDUCED_BYPASS  (REDUCED_BYPASS),
.MULDIV_UNROLL   (MULDIV_UNROLL),
.MUL_FAST        (MUL_FAST),
.MTVEC_WMASK     (MTVEC_WMASK),
.W_ADDR          (W_ADDR),
.W_DATA          (W_DATA)

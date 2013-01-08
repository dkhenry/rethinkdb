#include "rdb_protocol/op.hpp"
#include "rdb_protocol/err.hpp"

namespace ql {

class var_term_t : public op_term_t {
public:
    var_term_t(env_t *env, const Term2 *term) : op_term_t(env, term, argspec_t(1)) {
        int var = arg(0)->as_datum()->as_int();
        datum_val = env->top_var(var);
    }
private:
    const datum_t **datum_val;
    virtual val_t *eval_impl() {
        return new_val(*datum_val);
    }
    RDB_NAME("var");
};

} //namespace ql
// M2 target: F' FprimeDeframer dataIn path (libFuzzer entry point).
// Oracle: sanitizers and aborts only. F' asserts are reported as crashes and triaged, not counted as bugs (see F' #5923).
// Uses the F' unit-test tester so the component is wired exactly as in its unit tests.

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "FprimeDeframerTester.hpp"

namespace {

// The tester keeps clearHistory() and invoke_to_dataIn() protected. Re-export them publicly for the harness only.
class FuzzFprimeTester : public Svc::FprimeDeframerTester {
  public:
    using Svc::FprimeDeframerTester::clearHistory;
    using Svc::FprimeDeframerTester::invoke_to_dataIn;
    // Replay-only probe: number of frames emitted on dataOut during the last call.
    FwSizeType dataOutCount() const { return this->fromPortHistory_dataOut->size(); }
};

// Leaked on purpose: one tester for the whole process.
FuzzFprimeTester* tester() {
    static FuzzFprimeTester* instance = new FuzzFprimeTester();
    return instance;
}

}  // namespace

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    // Copy into an exact-size heap buffer so ASan sees any read past the input.
    U8* copy = static_cast<U8*>(std::malloc(size > 0 ? size : 1));
    if (copy == nullptr) {
        return 0;
    }
    if (size > 0) {
        std::memcpy(copy, data, size);
    }
    Fw::Buffer buffer(copy, static_cast<FwSizeType>(size));
    ComCfg::FrameContext context;

    FuzzFprimeTester* t = tester();
    t->clearHistory();
    t->invoke_to_dataIn(0, buffer, context);
    // Only when CT_REPLAY is set (manual replay of single files); fuzzing runs are unaffected.
    if (std::getenv("CT_REPLAY") != nullptr && t->dataOutCount() > 0) {
        std::fputs("DATAOUT_HIT\n", stderr);
    }
    std::free(copy);
    return 0;
}

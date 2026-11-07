// M2 target: F' SpacePacketDeframer dataIn path (libFuzzer entry point).
// Oracle: sanitizers and aborts only. F' asserts are reported as crashes and triaged, not counted as bugs (see F' #5923).
// Uses the F' unit-test tester so the component is wired exactly as in its unit tests.

#include <cstdint>
#include <cstdlib>
#include <cstring>

// The F' tester keeps clearHistory() and invoke_to_dataIn() protected, and the tester class is final, so it cannot
// be subclassed. Widen access for this one include only (access specifiers do not change layout). Harness-only hack.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wkeyword-macro"
#define protected public
#include "SpacePacketDeframerTester.hpp"
#undef protected
#pragma clang diagnostic pop

namespace {
// Leaked on purpose: one tester for the whole process, like one component instance per fuzz run.
Svc::Ccsds::SpacePacketDeframerTester* tester() {
    static Svc::Ccsds::SpacePacketDeframerTester* instance = new Svc::Ccsds::SpacePacketDeframerTester();
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

    Svc::Ccsds::SpacePacketDeframerTester* t = tester();
    t->clearHistory();
    t->invoke_to_dataIn(0, buffer, context);
    std::free(copy);
    return 0;
}

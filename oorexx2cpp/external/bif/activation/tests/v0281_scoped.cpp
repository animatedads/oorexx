#include "rxbif_v0281_scoped.hpp"
#include <cassert>
#include <atomic>
#include <exception>
#include <iostream>
#include <stdexcept>
#include <thread>
#include <string>
#include <vector>
using rxbif_v0281::ScopedActivation;
using rxbif_v0281::ThreadRouter;
static void reject(const std::function<void()>& f) {
    bool rejected=false;
    try{f();} catch(const std::exception&){rejected=true;}
    assert(rejected);
}
int main(){
    ThreadRouter router;
    reject([&]{(void)router.invoke("DIGITS");});
    rx::BifRuntime bif1,bif2;
    rx::Variables first,second;
    first.numeric.digits=12; first.numeric.fuzz=2;first.numeric.engineering=true;
    second.numeric.digits=5; second.numeric.fuzz=0; second.numeric.engineering=false;
    {
      ScopedActivation bound(bif1,first);
      assert(router.invoke("DIGITS").bytes=="12");
      assert(router.invoke("FUZZ").bytes=="2");
      assert(router.invoke("FORM").bytes=="ENGINEERING");
      first.numeric.digits=14;
      assert(router.invoke("DIGITS").bytes=="14");
      {
        ScopedActivation nested(bif2,second);
        assert(router.invoke("DIGITS").bytes=="5");
        assert(router.invoke("FORM").bytes=="SCIENTIFIC");
      }
      assert(router.invoke("DIGITS").bytes=="14");
      // Same activation may nest within its owning thread.
      {ScopedActivation again(bif1,first);assert(router.invoke("DIGITS").bytes=="14");}
      std::atomic<int> failures{0},successes{0};
      std::thread a([&]{
        reject([&]{ScopedActivation forbidden(bif1,second);});
        reject([&]{ScopedActivation forbidden(bif2,first);});
        ++failures;
      });
      std::thread b([&]{
        ScopedActivation isolated(bif2,second);
        if(router.invoke("DIGITS").bytes=="5" && router.invoke("FORM").bytes=="SCIENTIFIC") ++successes;
      });
      a.join();b.join();
      assert(failures==1 && successes==1);
      assert(router.invoke("DIGITS").bytes=="14");
      reject([&]{(void)router.invoke("ARG");}); // no frame supplier
      // No hidden replacement when numeric settings are invalid.
      first.numeric.fuzz=14;
      reject([&]{(void)router.invoke("DIGITS");});
      first.numeric.fuzz=2;
    }
    reject([&]{(void)router.invoke("DIGITS");});
    {
      ScopedActivation after(bif1,first);
      assert(router.invoke("DIGITS").bytes=="14");
    }
    std::cout<<"PASS v0.28.1 scoped BIF activation: nested, dynamic numeric, cross-thread isolation\n";
}

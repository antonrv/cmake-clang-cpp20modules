module;

#include "foo.h"

module helloworld;

import <iostream>;

void hello() {
    auto f = foo<int>();
    std::cout << "Hello world. Foo return: " << f << "!\n";
}

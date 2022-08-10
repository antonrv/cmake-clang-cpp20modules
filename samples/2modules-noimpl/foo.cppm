export module Foo;

import <iostream>;
import <string>;

export void foo(std::string msg)
{
    std::cout << "From foo got message: `" << msg << "`\n";
}

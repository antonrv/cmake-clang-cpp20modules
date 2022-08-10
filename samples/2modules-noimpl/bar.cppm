export module Bar;

import Foo;

import <string>;

export void bar()
{
    foo(std::string("sent from bar"));
}

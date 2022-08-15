module Bar;

import Foo;
import <string>;

void bar()
{
    foo(std::string("sent from bar"));
}

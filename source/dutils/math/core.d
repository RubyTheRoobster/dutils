module dutils.math.core;

version(DLL)
{
	mixin("export:");
}

else
{
	mixin("public:");
}

import std.complex;

alias Operator = dstring function(dstring input);

//List of all operations.
package Operator[dstring] opList;

//List of all functions.
package dstring[dstring] funcList;

//Initialize the basic arithmetic operations to null: these will be handled by operator overloading.
shared static this()
{
    opList["+"d] = null;
	opList["-"d] = null;
	opList["*"d] = null;
	opList["/"d] = null;
	opList["^^"d] = null;
}

//An interface that serves as the basis for all math types.
package interface mType
{
	mType opBinary(string op)(mType rhs);
	mType opBinary(string op)(Complex!real rhs);
	
	mType opBinaryRight(string op)(mType lhs);
	mType opBinaryRight(string op)(Complex!real lhs);
	
	mType opUnary(string op);
}

/**************************************************
 * Validates the math library's fucntion syntax.
 *
 * TODO: Make syntax rules modular.
 *
 * Params:
 *     funcbody = The body of the function to validate.
 * Returns: true if the function has correct syntax,
 *          false otherwise.
 */
bool validateFunction(dstring funcbody) nothrow pure @safe @nogc
{
	import std.uni : isSpace, isNumber;
	
	long indentation = 0; //Indentation level;
	bool isOp = false;  //If there is a current operator being used.
	bool isNum = false;  //If there is currently a number in use.
	bool isDec = false; //If there is already a decimal point in the number.
    bool isx = false;  //If the current number is 'x'.
    bool isEverNum = false;  //If there is at least one number in the function body.
	ubyte powCount = 0; //Internal counter for ^^ operator.
	
	foreach(c; funcbody)
	{
	    Switch: switch(c)
		{
			case cast(dchar)'x':
                isx = true;
				isOp = false;
                isNum = true;
                isEverNum = true;
                isDec = false;
			    break;
				
			static foreach(x; [cast(dchar)'+', cast(dchar)'-', cast(dchar)'*', cast(dchar)'/']) //Iterate over validating the basic four operators.
			{
				case x:
					if(isOp || !isNum)
						return false;
						
					isOp = true;
					powCount = 0;
                    isNum = false;
                    isDec = false;
                    isx = false;
					break Switch;
			}
			
			case cast(dchar)'^': //Take care of exponents.
				if(isOp || !isNum)
					return false;
					
				switch(powCount)
				{
					case 0:
						++powCount;
						break;
					case 1:
						++powCount;
						isOp = true;
						break;
					default:
						return false;
				}
                isNum = false;
                isDec = false;
                isx = false;
				break;
            case cast(dchar)'(': //Indentation
                ++indentation;
                break;
            case cast(dchar)')':
                --indentation;
                break;
			default:
			     if(isNumber(c) || c == cast(dchar)'i') //Imaginary numbers are numbers.
                 {
                    isNum = true;
                    isx = false;
                    isEverNum = true;
                    isOp = false;
                    break;
                 }
                 else if(c == cast(dchar)'.')  //Dissallow multiple decimal points.
                 {
                    if(!isDec && isNum && !isx)
                        isDec = true;
                    else
                        return false;
                    break;
                 }
                 else if(isSpace(c))
                    break;
                 else
                    return false;
        }
    }
    if(indentation != 0 || !isEverNum || powCount != 0 || isOp)  //Final conditions that have to be met.
        return false;
    return true;
}

///
unittest
{
    dstring func = "x + 1"d;
    assert(validateFunction(func));
    func = "x^^2 + 2^^2 j- 3"d;
    assert(!validateFunction(func));
    func = "x.3";
    assert(!validateFunction(func));
    func = "()";
    assert(!validateFunction(func));
    func = "x ^ 3";
    assert(!validateFunction(func));
    func = "x +";
    assert(!validateFunction(func));
    assert(!validateFunction("x ++ 1"d));
}

/*******************************************************************
 * Registers a function with the given name and function body.
 * 
 * Params:
 *     funcdef = The definition of the function to register.
 *     funcbody = The body of the function to register.
 *
 * Returns:
 *     True if the function successfuly registers, false
 *     otherwise.
 */
bool registerFunction(dstring funcdef, dstring funcbody) @safe nothrow
{
    uint index = 0;
    bool openParam = false;
    Loop:
    for (uint i = 0; i < funcdef.length; i++) //Make sure the function is defined along the lines of a(x) = num(num).
    {
        switch(funcdef[i])
        {
            case cast(dchar)'=':
                 if(openParam)
                    return false;
                 index = i;
                 break Loop;
            case cast(dchar)'(':
                if(openParam)
                    return false;
                index = i;
                openParam = true;
                break;
            case cast(dchar)')':
                if(!openParam)
                    return false;
                openParam = false;
                break;
            default:
                if(index == i-1 && openParam)
                {
                    if(funcdef[i] != cast(dchar)'x')
                        return false;
                }
        }
    }
    
    if(funcdef[index .. $] != "= num(num)"d)
        return false;            
                
    if(validateFunction(funcbody) && funcdef !in funcList) //Validate the function and make sure that it isn't already defined.
    {
        funcList[funcdef] = funcbody;
        return true;
    }
    return false;
}

///
unittest
{
    dstring func = "x + 1"d;
    assert(registerFunction("a(x) = num(num)"d,func));
    func = "x^^2 + 2^^2 j- 3"d;
    assert(!registerFunction("a(x) = num(num)"d,func));
    func = "x.3";
    assert(!registerFunction("a(x) = num(num)"d,func));
    func = "()";
    assert(!registerFunction("a(x) = num(num)"d,func));
    func = "x ^ 3";
    assert(!registerFunction("a(x) = num(num)"d,func));
    func = "x +";
    assert(!registerFunction("a(x) = num(num)"d,func));
    assert(!registerFunction("a(x) = num(num)"d,"x ++ 1"d));
    assert(registerFunction("b(x) = num(num)"d, "x"d));
    assert(!registerFunction("a(x) = num(num)"d, "x"d));
}

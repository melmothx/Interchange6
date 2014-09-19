#! perl -T
#
# Tests for Interchange6::Cart costs.

use strict;
use warnings;

use Data::Dumper;
use Test::Most 'die';

use Interchange6::Cart;

my ( $cart, $product, $ret );

$cart = Interchange6::Cart->new;

throws_ok(
    sub { $cart->apply_cost() },
    qr/argument to apply_cost undefined/,
    "fail apply_cost with empty args"
);

throws_ok(
    sub { $cart->apply_cost(undef) },
    qr/argument to apply_cost undefined/,
    "fail apply_cost with undef arg"
);

my $ref = { foo => 'bar' };
bless $ref, "Some::Bad::Class";

throws_ok(
    sub { $cart->apply_cost($ref) },
    qr/Supplied cost not an Interchange6::Cart::Cost : Some::Bad::Class/,
    "fail apply_cost with bad class as arg"
);

throws_ok(
    sub { $cart->apply_cost( amount => 5 ) },
    qr/Missing required arguments: name/,
    "fail apply_cost with arg amount only"
);

throws_ok(
    sub { $cart->apply_cost( name => 'fee' ) },
    qr/Missing required arguments: amount/,
    "fail apply_cost with arg amount only"
);

# fixed amount to empty cart
lives_ok( sub { $cart->apply_cost( amount => 5, name => 'fee' ) },
    "apply_cost 5 with name fee" );

cmp_ok( $cart->cost_count, '==', 1, "cost_count is 1" );

cmp_ok( $cart->costs->[0]->label, 'eq', 'fee', "cost label lazily set to fee" );

cmp_ok( $cart->total, '==', 5, "cart total is 5" );

throws_ok(
    sub { $cart->cost() },
    qr/position or name required/,
    "fail calling cost with no arg"
);

throws_ok(
    sub { $cart->cost(' ') },
    qr/Bad argument to cost:/,
    "fail calling cost with single space as arg"
);

throws_ok(
    sub { $cart->cost("I'm not there") },
    qr/Bad argument to cost:/,
    "fail calling cost with bad cost name"
);

# get cost by position
$ret = $cart->cost(0);
ok( $ret == 5, "Total: $ret" );

# get cost by name
$ret = $cart->cost('fee');
ok( $ret == 5, "Total: $ret" );

lives_ok( sub { $cart->clear_costs() }, "Clear costs" );

# relative amount to empty cart
$cart->apply_cost( name => 'tax', amount => 0.5, relative => 1 );

lives_ok( sub { $ret = $cart->total }, "get cart total" );
ok( $ret == 0, "Total: $ret" );

lives_ok( sub { $cart->clear_costs }, "Clear costs" );

# relative amount to cart with one product
$product = { sku => 'ABC', name => 'Foobar', price => 22 };
lives_ok( sub { $ret = $cart->add($product) }, "add product ABC" );

cmp_ok( $cart->count, '==', 1, "one product in cart" );

$cart->apply_cost( amount => 0.5, relative => 1, name => 'megatax' );

$ret = $cart->total;
ok( $ret == 33, "Total: $ret" );

$ret = $cart->cost(0);
ok( $ret == 11, "Cost: $ret" );

$ret = $cart->cost('megatax');
ok( $ret == 11, "Cost: $ret" );

$cart->clear_costs;

# relative and inclusive amount to cart with one product
$cart->apply_cost(
    amount    => 0.5,
    relative  => 1,
    inclusive => 1,
    name      => 'megatax'
);

$ret = $cart->total;
ok( $ret == 22, "Total: $ret" );

$ret = $cart->cost(0);
ok( $ret == 11, "Cost: $ret" );

$ret = $cart->cost('megatax');
ok( $ret == 11, "Cost: $ret" );

$cart->clear;

# product costs...

$product = { sku => 'ABC', name => 'Foobar', price => 22, quantity => 2 };
lives_ok( sub { $product = $cart->add($product) }, "Add 2 x product ABC to cart" );
cmp_ok( $product->subtotal, '==', 44, "product subtotal is 44" );
cmp_ok( $product->total, '==', 44, "product total is 44" );
cmp_ok( $cart->subtotal, '==', 44, "cart subtotal is 44" );
cmp_ok( $cart->total, '==', 44, "cart total is 44" );

lives_ok( sub { $product->discount_percent(20) },
    "Apply 20% discount to product");

ok( !$product->has_price, "product price has been cleared" );
ok( !$product->has_subtotal, "product subtotal has been cleared" );
ok( !$product->has_total, "product total has been cleared" );
cmp_ok( $product->subtotal, '==', 35.20, "product subtotal is 35.20" );
cmp_ok( $product->total, '==', 35.20, "product total is 35.20" );
cmp_ok( $cart->subtotal, '==', 35.20, "cart subtotal is 35.20" );
cmp_ok( $cart->total, '==', 35.20, "cart total is 35.20" );

lives_ok(
    sub {
        $product->apply_cost(
            amount   => 0.18,
            name     => 'tax',
            label    => 'VAT',
            relative => 1,
        )
    }, "Add 18% VAT to discounted product"
);
ok( $product->has_price, "product price has not been cleared" );
ok( $product->has_subtotal, "product subtotal has not been cleared" );
ok( !$product->has_total, "product total has been cleared" );
cmp_ok( $product->subtotal, '==', 35.20, "product subtotal is 35.20" );
cmp_ok( $product->total, '==', 41.54, "product total is 41.54" );
cmp_ok( $product->cost('tax'), '==', 6.34, "product tax is 6.34" );
cmp_ok( $cart->subtotal, '==', 41.54, "cart subtotal is 41.54" );
cmp_ok( $cart->total, '==', 41.54, "cart total is 41.54" );

lives_ok( sub { $cart->discount_percent(2) }, "apply 2% cart discount" );
cmp_ok( $product->cart->discount_percent, '==', 2, "cart discount_percent is 2" );
cmp_ok( $product->subtotal, '==', 34.50, "product subtotal is 34.50" );
cmp_ok( $product->total, '==', 40.71, "product total is 40.71" );
cmp_ok( $product->cost('tax'), '==', 6.21, "product tax is 6.21" );
cmp_ok( $cart->subtotal, '==', 40.71, "cart subtotal is 40.71" );
cmp_ok( $cart->total, '==', 40.71, "cart total is 40.71" );

my $product2 = { sku => 'DEF', name => 'Banana', price => 33, quantity => 3 };
lives_ok( sub { $product2 = $cart->add($product2) }, "Add 3 x product DEF to cart" );
ok( !$product2->has_price, "product price is not set" );
ok( !$product2->has_subtotal, "product subtotal is not set" );
ok( !$product2->has_total, "product total is not set" );
cmp_ok( $product2->price, '==', 32.34, "product price is 32.34" );
cmp_ok( $product2->subtotal, '==', 97.02, "product subtotal is 97.02" );
cmp_ok( $product2->total, '==', 97.02, "product total is 97.02" );
cmp_ok( $cart->subtotal, '==', 137.73, "cart subtotal is 137.73" );
cmp_ok( $cart->total, '==', 137.73, "cart total is 137.73" );

lives_ok( sub { $cart->discount_percent(0) }, "change cart discount to zero" );
cmp_ok( $product->cart->discount_percent, '==', 0, "cart discount_percent is 0" );
cmp_ok( $product->price, '==', 17.60, "product1 price is 17.60" );
cmp_ok( $product->subtotal, '==', 35.20, "product1 subtotal is 35.20" );
cmp_ok( $product->total, '==', 41.54, "product1 total is 41.54" );
cmp_ok( $product->cost('tax'), '==', 6.34, "product1 tax is 6.34" );
cmp_ok( $product2->price, '==', 33, "product price is 33" );
cmp_ok( $product2->subtotal, '==', 99, "product subtotal is 99" );
cmp_ok( $product2->total, '==', 99, "product total is 99" );
cmp_ok( $cart->subtotal, '==', 140.54, "cart subtotal is 140.54" );
cmp_ok( $cart->total, '==', 140.54, "cart total is 140.54" );
done_testing;

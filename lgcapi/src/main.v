module main

import db.sqlite
import veb
import rand
import time

@[table: 'currencies']
struct Currency {
	id   int @[primary; serial]
	name string
}

@[table: 'users']
struct User {
	id          int @[primary; serial]
	address     string
	private_key string
}

@[table: 'transactions']
struct Transaction {
	id        int @[primary; serial]
	currency  string
	amount    int
	timestamp i64
	sender    string
	reciever  string
}

pub struct Context {
	veb.Context
}

pub struct App {
mut:
	database sqlite.DB
}

pub fn (app &App) index(mut ctx Context) veb.Result {
	return ctx.file('src/index.html')
}

@['/create/user'; get]
pub fn (app &App) create_user(mut ctx Context) veb.Result {
	address := rand.hex(24)
	key := rand.hex(128)
	user := User{
		address:     address
		private_key: key
	}
	sql app.database {
		insert user into User
	} or { return ctx.text('somefing went wrong af') }
	return ctx.text('{"address": "${address}", "key": "${key}"}')
}

@['/check/user/:privatekey']
pub fn (app &App) check_user(mut ctx Context, pk string) veb.Result {
	user := sql app.database {
		select from User where private_key == pk
	} or { return ctx.text('something went wrong with fetching the user!') }
	if user.len < 1 {
		return ctx.text('user doesnt exist')
	}
	return ctx.text(user.first().address)
}

@['/check/currency/:name']
pub fn (app &App) check_currency(mut ctx Context, currency_name string) veb.Result {
	currency := sql app.database {
		select from Currency where name == currency_name
	} or { return ctx.text('something went wrong with fetching the currency') }
	if currency.len < 1 {
		return ctx.text('currency doesnt exist')
	}
	return ctx.text('success')
}

@['/create/currency/:currency_name/:private_key/:inital_balance'; get]
pub fn (app &App) create_currency(mut ctx Context, currency_name string, private_key string, initial_balance int) veb.Result {
	if currency_name.len > 32 {
		return ctx.text('currency name cannot be more than 32 characters.')
	}
	if initial_balance < 1 {
		return ctx.text('initial balance must be atleast 1.')
	}
	user := sql app.database {
		select from User where private_key == private_key
	} or { return ctx.text('something went wrong with fetching the user!') }
	if user.len != 1 {
		return ctx.text('user doesnt exist!')
	}
	if user.first().address == 'burn' {
		return ctx.text('you cannot create a currency from burn.')
	}
	old_currency := sql app.database {
		select from Currency where name == currency_name
	} or { return ctx.text('something went wrong with getting the currency name!') }
	if old_currency.len != 0 {
		return ctx.text('currency already exists!')
	}
	currency := Currency{
		name: currency_name
	}
	sql app.database {
		insert currency into Currency
	} or { return ctx.text('something went wrong with creating currency!') }

	tx := Transaction{
		sender:   'genesis'
		reciever: user.first().address
		currency: currency_name
		amount:   initial_balance
		timestamp: time.utc().unix_micro()
	}
	sql app.database {
		insert tx into Transaction
	} or { ctx.text('something went wrong with creating transaction!') }

	return ctx.text('success')
}

@['/get/balance/:user/:currency']
fn (app &App) get_balance(mut ctx Context, username string, currency string) veb.Result {
	transactions := sql app.database {
		select from Transaction where (reciever == username || sender == username)
		&& currency == currency
	} or { return ctx.text('something went wrong with fetching transactions!') }
	if transactions.len == 0 {
		return ctx.text('No transactions matched this query')
	}
	mut total_balance := 0
	for i in transactions {
		if i.reciever == username {
			total_balance += i.amount
		} else {
			total_balance -= i.amount
		}
	}
	return ctx.text('${total_balance}')
}

@['/get/transactions/:user']
fn (app &App) get_transactions(mut ctx Context, username string) veb.Result {
	transactions := sql app.database {
		select from Transaction where reciever == username || sender == username
	} or { return ctx.text('something went wrong in getting transactions') }
	if transactions.len == 0 {
		return ctx.text('No transactions matched this query')
	}
	return ctx.json(transactions)
}

@['/create/transaction/:private_key/:reciever/:amount/:currency']
fn (app &App) send_transaction(mut ctx Context, key string, reciever string, amount int, currency string) veb.Result {
	if amount < 1 {
		return ctx.text('minimum transaction is 1')
	}
	user := sql app.database {
		select from User where private_key == key
	} or { return ctx.text('something went wrong with fetching the user!') }
	if user.len != 1 {
		return ctx.text('sender doesnt exist!')
	}
	if user.first().address == 'burn' {
		return ctx.text('you cannot send from burn.')
	}
	currency_check := sql app.database {
		select from Currency where name == currency
	} or { return ctx.text('something went wrong with fetching the currency!') }
	if currency_check.len != 1 {
		return ctx.text('currency doesnt exist!')
	}
	user2 := sql app.database {
		select from User where address == reciever
	} or { return ctx.text('something went wrong with fetching the user!') }
	if user2.len != 1 {
		return ctx.text('reciever doesnt exist!')
	}
	if user.first().address == reciever {
		return ctx.text('U CANT SEND MONEY TO URSELF IDIOT')
	}
	transactions := sql app.database {
		select from Transaction where
		(reciever == user.first().address || sender == user.first().address) && currency == currency
	} or { return ctx.text('something went wrong with fetching transactions!') }
	if transactions.len == 0 {
		return ctx.text('No transactions matched this query')
	}
	mut total_balance := 0
	for i in transactions {
		if i.reciever == user.first().address {
			total_balance += i.amount
		} else {
			total_balance -= i.amount
		}
	}
	if total_balance < amount {
		return ctx.text('U DONT HAVE ENOUGH MONEY')
	}

	transaction := Transaction{
		sender:   user.first().address
		currency: currency
		reciever: reciever
		amount:   amount
		timestamp: time.utc().unix_micro()
	}

	sql app.database {
		insert transaction into Transaction
	} or { return ctx.text('DA TRANSACTION FAILED TO BE CREATED :(') }

	return ctx.text('success')
}

fn main() {
	mut app := &App{
		database: sqlite.connect('database.db')!
	}
	sql app.database {
		create table Currency
		create table User
		create table Transaction
	}!
	burn_u := sql app.database {
		select from User where address == 'burn'
	}!
	if burn_u.len < 1 {
		burn := User{
			address:     'burn'
			private_key: ''
		}
		sql app.database {
			insert burn into User
		}!
	}
	// Pass the App and context type and start the web server on port 8080
	veb.run[App, Context](mut app, 54213)
}

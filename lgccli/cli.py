import requests
import os
import json
import datetime

server = 'http://38.46.221.76:54213'
key = ''

class style():
    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'
    UNDERLINE = '\033[4m'
    RESET = '\033[0m'

def try_get_name(pk):
    t = requests.get(server + "/check/user/"+pk).text
    if t in ["something went wrong with fetching the user!", "user doesnt exist"]:
        return False
    return t

def main():
    global key
    print(style.BLUE + "Luna General Currency CLI.")
    if not os.path.exists("pk"):
        print(style.WHITE + "(enter none if you want to generate a new one)")
        pk = input(style.WHITE + "What is your private key: ")
        if pk.strip() == "":
            print("Creating new account!")
            u = json.loads(requests.get(server + "/create/user").text)
            key = u['key']
        else:
            key = pk
            if not try_get_name(key):
                print(style.RED + "Invalid key...")
                exit(1)
        open("pk", "w").write(key)
    else:
        key = open("pk", "r").read()

    n = try_get_name(key)
    if not n:
        print(style.RED + "Invalid key...")
        exit(1)
    print(style.WHITE + "Welcome, " + n)
    print(style.RED + "NEVER SHARE YOUR PRIVATE KEY WITH ANYONE.")
    print(style.RED + "(private key is stored in the file named pk)")
    currency = "none"
    while True:
        i = input(style.WHITE + f"[{n[0:9]}.... @ {currency}] > ")
        if i == "":
            print("type ? for help")
        elif i == "?":
            print("""
            switch - opens prompt for switching currencies
            balance - opens prompt for getting balances
            transactions - opens prompt for getting transactions
            create - opens prompt for making new currency
            send - opens prompt for sending money
            address - prints full address
            """)
        elif i == "switch":
            c = input("Currency name: ")
            if requests.get(server + "/check/currency/"+c).text != "success":
                print(style.RED + "invalid currency...")
            else:
                currency = c
        elif i == "balance":
            if currency == "none":
                print(style.RED + "Switch to a currency before running this command.")
                continue
            print(style.YELLOW + "Leave blank to get your own balance")
            c = input(style.WHITE + "Address: ")
            if c.strip() == "":
                c = n
            f = requests.get(server + f"/get/balance/{c}/{currency}").text
            try:
                print(f"Balance of {c}: " + currency + "$" + str(int(f)))
            except:
                print(style.RED + f)
        elif i == "transactions":
            print(style.YELLOW + "Leave blank to get your own transactions")
            c = input(style.WHITE + "Address: ")
            if c.strip() == "":
                c = n
            f = requests.get(server + f"/get/transactions/{c}").text
            if f == "No transactions matched this query":
                print(style.RED + "No transactions found.")
                continue
            j = json.loads(f)
            balances = {
                
            }
            for i in j:
                if i['currency'] not in balances:
                    balances[i['currency']] = 0
                if i['sender'] == c:
                    balances[i['currency']] -= i['amount']
                    print(f"""
    {i['reciever']} <- {style.YELLOW}{i['sender']}{style.RESET}. 
    amount: {i['currency']}${i['amount']} 
    at {datetime.datetime.fromtimestamp(i['timestamp']/1000/1000, datetime.datetime.now().astimezone().tzinfo)}
""")
                else:
                    balances[i['currency']] += i['amount']
                    print(f"""
    {i['sender']} -> {style.YELLOW}{i['reciever']}{style.RESET}. 
    amount: {i['currency']}${i['amount']} 
    at {datetime.datetime.fromtimestamp(i['timestamp']/1000/1000, datetime.datetime.now().astimezone().tzinfo)}
""")
                print(f"\tBalance after: {i['currency']}${balances[i['currency']]}")
        elif i == "address":
            print(n)
        elif i == "create":
            print(style.YELLOW + "Leave blank to cancel.")
            c = input(style.WHITE + "Currency name: ")
            if c.strip() == "":
                continue
            a = input(style.WHITE + "Starting amount: ")
            if a.strip() == "":
                continue
            t = requests.get(server + f"/create/currency/{c}/{key}/{a}").text
            if t != "success":
                print(style.RED, t)
                continue
            print("Created!")
        elif i == "send":
            if currency == "none":
                print(style.RED + "Switch to a currency before running this command.")
                continue
            print(style.YELLOW + "Leave blank to cancel.")
            r = input(style.WHITE + "Recipient: ")
            if r.strip() == "":
                continue
            a = input(style.WHITE + "Amount: ")
            if a.strip() == "":
                continue
            try:
                int(a)
            except:
                print(f"{a} is not a number.")
                continue
            print(f"{style.RED}Are you sure you want to send {currency}${a} to {r}")
            yn = input("[Y/N] ")
            if yn.upper() != "Y":
                continue
            t = requests.get(server + f"/create/transaction/{key}/{r}/{a}/{currency}").text
            if t != 'success':
                print(t)
            else:
                print(f"{style.GREEN}Sent!")

if __name__ == "__main__":
    main()
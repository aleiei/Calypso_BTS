import os
import sys
import subprocess
import sqlite3
import telnetlib
from tkinter import *
from tkinter import ttk
from tkinter import messagebox


terminal_pids = []

def open_terminal(script):
    proc = subprocess.Popen(['sudo', 'x-terminal-emulator', '-e', script])
    terminal_pids.append(proc.pid)

def click_button():
    open_terminal('./trx2.sh')

def click_button2():
    open_terminal('./transceiver.sh')

def click_button3():
    open_terminal('./nitb.sh')

def click_button4():
    open_terminal('./osmobts.sh')

def click_button5():
    subprocess.Popen(['xdg-open', '/usr/src/CalypsoBTS/openbsc.cfg'])

def click_button6():
    subprocess.Popen(['xdg-open', '/usr/src/CalypsoBTS/osmo-bts-trx-calypso.cfg'])

def click_button7():
    db_path = '/usr/src/CalypsoBTS/hlr.sqlite3'
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM Subscriber")
        rows = cursor.fetchall()
        conn.close()
        if rows:
            msg = "ID  |  IMSI             |  MSISDN\n" + "-"*45 + "\n"
            msg += "\n".join(f"{r[0]}  |  {r[3]:<15}  |  {r[5]}" for r in rows)
        else:
            msg = "No subscribers found."
    except Exception as e:
        msg = f"DB read error:\n{e}"
    messagebox.showinfo(title='Subscribers', message=msg)

def click_button8():
    subprocess.run(['sudo', 'rm', '-f', '/usr/src/CalypsoBTS/hlr.sqlite3'])
    messagebox.showinfo(title='Database', message='Database removed.')

def click_button9():
    db_path = '/usr/src/CalypsoBTS/hlr.sqlite3'
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT id, imsi, extension FROM Subscriber WHERE extension IS NOT NULL AND extension != '' AND extension != '111'")
        rows = cursor.fetchall()
        conn.close()
    except Exception as e:
        messagebox.showerror(title='DB Error', message=str(e))
        return

    if not rows:
        messagebox.showwarning(title='SMS', message='No subscriber with a valid number found.')
        return

    win = Toplevel(root)
    win.title("Send SMS")
    win.resizable(False, False)

    Label(win, text="Select recipients:", font=("Arial", 12, "bold")).pack(pady=8)

    frame_check = Frame(win, relief=SUNKEN, bd=1)
    frame_check.pack(padx=15, pady=4, fill=X)

    check_vars = []
    for r in rows:
        var = BooleanVar(value=True)
        check_vars.append(var)
        Checkbutton(frame_check,
                    text=f"Number: {r[2]}  |  IMSI: {r[1]}",
                    variable=var,
                    font=("Arial", 11), anchor=W).pack(fill=X, padx=8, pady=3)

    Label(win, text="Message:", font=("Arial", 10)).pack(pady=(4, 2))
    msg_entry = Entry(win, width=42, font=("Arial", 11))
    msg_entry.insert(0, "SMS test")
    msg_entry.pack(padx=15)
    msg_entry.focus_set()

    def ensure_sms_sender_111():
        sender_imsi = "999999999999999"
        try:
            tn = telnetlib.Telnet("127.0.0.1", 4242, timeout=5)
            tn.read_until(b"OpenBSC> ", timeout=5)

            tn.write(b"show subscriber extension 111\n")
            ext_res = tn.read_until(b"OpenBSC> ", timeout=5)

            if b"No subscriber found for extension" in ext_res:
                tn.write(f"show subscriber imsi {sender_imsi}\n".encode())
                imsi_res = tn.read_until(b"OpenBSC> ", timeout=5)

                if b"No subscriber found for imsi" in imsi_res:
                    tn.write(f"subscriber create imsi {sender_imsi}\n".encode())
                    create_res = tn.read_until(b"OpenBSC> ", timeout=5)
                    if b"%" in create_res:
                        tn.close()
                        return False, create_res.decode(errors="ignore")

                tn.write(b"enable\n")
                tn.read_until(b"OpenBSC# ", timeout=5)

                tn.write(f"subscriber imsi {sender_imsi} extension 111\n".encode())
                set_res = tn.read_until(b"OpenBSC# ", timeout=5)

                tn.write(b"disable\n")
                tn.read_until(b"OpenBSC> ", timeout=5)

                if b"%" in set_res:
                    tn.close()
                    return False, set_res.decode(errors="ignore")

            tn.close()
            return True, ""
        except Exception as e:
            return False, str(e)

    def send(event=None):
        ok_sender, sender_err = ensure_sms_sender_111()
        if not ok_sender:
            messagebox.showerror(title='SMS Error', message=f'Unable to create sender 111:\n{sender_err}')
            return

        selected = [(rows[i][0], rows[i][2]) for i, v in enumerate(check_vars) if v.get()]
        if not selected:
            messagebox.showwarning(title='SMS', message='Select at least one recipient.')
            return
        message = msg_entry.get().strip() or "SMS test"
        sent = []
        errors = []
        for dest_id, dest_ext in selected:
            try:
                tn = telnetlib.Telnet("127.0.0.1", 4242, timeout=5)
                tn.read_until(b"OpenBSC> ")
                cmd = f"subscriber id {dest_id} sms sender extension 111 send {message}\n"
                tn.write(cmd.encode())
                sms_res = tn.read_until(b"OpenBSC> ")
                tn.close()
                if b"%" in sms_res:
                    errors.append(f"{dest_ext}: {sms_res.decode(errors='ignore').strip()}")
                else:
                    sent.append(dest_ext)
            except Exception as e:
                errors.append(f"{dest_ext}: {e}")
        win.destroy()
        if sent:
            messagebox.showinfo(title='SMS', message=f'SMS sent to: {", ".join(sent)}')
        if errors:
            messagebox.showerror(title='SMS Error', message='\n'.join(errors))

    msg_entry.bind("<Return>", send)
    win.bind("<Return>", send)

    Button(win, text="Send SMS", background="#FFD700", foreground="#000",
           padx=30, pady=8, font=("Arial", 12, "bold"), command=send).pack(pady=14)

def click_button_killall():
    procs = ['osmocon', 'transceiver', 'osmo-nitb', 'osmo-bts-trx']
    killed = []
    for p in procs:
        result = subprocess.run(['sudo', 'pkill', '-f', p])
        if result.returncode == 0:
            killed.append(p)
    scripts = ['trx.sh', 'trx2.sh', 'transceiver.sh', 'nitb.sh', 'osmobts.sh', 'console.sh']
    for s in scripts:
        subprocess.run(['sudo', 'pkill', '-f', s])
    for pid in terminal_pids:
        subprocess.run(['sudo', 'kill', str(pid)])
    terminal_pids.clear()
    if killed:
        messagebox.showinfo(title='Kill All', message='Terminated:\n' + '\n'.join(killed))
    else:
        messagebox.showinfo(title='Kill All', message='No running process found.')

def click_button10():
    open_terminal('./console.sh')

def click_button11():
    subprocess.Popen(['xdg-open', 'transceiver.sh'])

def click_button12():
    subprocess.Popen(['xdg-open', 'trx.sh'])

def click_button13():
    open_terminal('./trx.sh')

def click_button14():
    subprocess.Popen(['xdg-open', 'trx2.sh'])


root = Tk()
root.title("Calypso BTS")
root.geometry("600x400")
root.minsize(600, 400)
root.resizable(True, True)

img = PhotoImage(file='ico.png')
root.tk.call('wm', 'iconphoto', root._w, img)

tab_control = ttk.Notebook(root)
tab1 = ttk.Frame(tab_control)
tab2 = ttk.Frame(tab_control)
tab3 = ttk.Frame(tab_control)

tab_control.add(tab1, text='BTS')
tab_control.add(tab2, text='Subscribers')
tab_control.add(tab3, text='Help')

tab1.columnconfigure(0, weight=1)
tab1.rowconfigure(0, weight=1)
tab2.columnconfigure(0, weight=1)
tab2.rowconfigure(0, weight=1)
tab3.columnconfigure(0, weight=1)
tab3.rowconfigure(0, weight=1)

bts_panel = ttk.Frame(tab1)
bts_panel.grid(column=0, row=0, padx=12, pady=12)
bts_panel.columnconfigure((0, 1, 2, 3, 4, 5), weight=1)

sub_panel = ttk.Frame(tab2)
sub_panel.grid(column=0, row=0, padx=12, pady=12)
sub_panel.columnconfigure((0, 1), weight=1)

help_text = (
    "Simple Calypso BTS\n\n"
    "Correct startup sequence:\n"
    "TRX1 (or TRX1 + TRX2) > Clock > DB > BTS\n\n"
    "Alessandro Orlando (C) 2026 GPL v3"
)
lbl3 = ttk.Label(tab3, text=help_text, justify=CENTER, anchor='center', wraplength=560)
lbl3.grid(column=0, row=0, sticky='nsew', padx=16, pady=16)

tab_control.pack(expand=1, fill='both')


btn5 = Button(bts_panel, text="OpenBSC Config", background="#00C957", foreground="#000",
              padx="40", pady="10", font="16", command=click_button5)
btn5.grid(column=1, row=0, columnspan=2, padx=8, pady=8)

btn6 = Button(bts_panel, text="OsmoBTS Config", background="#00C957", foreground="#000",
              padx="40", pady="10", font="16", command=click_button6)
btn6.grid(column=3, row=0, columnspan=2, padx=8, pady=8)

btn12 = Button(bts_panel, text="⚙", background="#B7B7B7", foreground="#000",
               padx="8", pady="5", font="50", command=click_button12)
btn12.grid(column=0, row=1, padx=6, pady=8)

btn13 = Button(bts_panel, text="TRX1", background="#B7B7B7", foreground="#000",
               padx="12", pady="10", font="16", command=click_button13)
btn13.grid(column=1, row=1, padx=6, pady=8)

btn = Button(bts_panel, text="TRX2", background="#B7B7B7", foreground="#000",
             padx="12", pady="10", font="16", command=click_button)
btn.grid(column=2, row=1, padx=6, pady=8)

btn14 = Button(bts_panel, text="⚙", background="#B7B7B7", foreground="#000",
               padx="8", pady="5", font="50", command=click_button14)
btn14.grid(column=3, row=1, padx=6, pady=8)

btn2 = Button(bts_panel, text="Clock", background="#40E0D0", foreground="#000",
              padx="50", pady="10", font="16", command=click_button2)
btn2.grid(column=4, row=1, padx=6, pady=8)

btn11 = Button(bts_panel, text="⚙", background="#40E0D0", foreground="#000",
               padx="8", pady="5", font="50", command=click_button11)
btn11.grid(column=5, row=1, padx=6, pady=8)

btn3 = Button(bts_panel, text="Database", background="#B7B7B7", foreground="#000",
              padx="50", pady="10", font="16", command=click_button3)
btn3.grid(column=1, row=2, columnspan=2, padx=8, pady=10)

btn4 = Button(bts_panel, text="! BTS !", background="#FF0000", foreground="#000",
              padx="50", pady="10", font="16", command=click_button4)
btn4.grid(column=3, row=2, columnspan=2, padx=8, pady=10)

btn_kill = Button(bts_panel, text="⏹ Kill All", background="#8B0000", foreground="#FFFFFF",
                  padx="30", pady="10", font="16", command=click_button_killall)
btn_kill.grid(column=0, row=3, columnspan=6, pady=14)

btn8 = Button(sub_panel, text="Delete Database", background="#1A1A1A", foreground="#FF0000",
              padx="40", pady="10", font="16", command=click_button8)
btn8.grid(column=0, row=0, padx=10, pady=8)

btn7 = Button(sub_panel, text="Subscribers", background="#E066FF", foreground="#000",
              padx="40", pady="10", font="16", command=click_button7)
btn7.grid(column=1, row=0, padx=10, pady=8)

btn9 = Button(sub_panel, text="Test SMS", background="#FFD700", foreground="#000",
              padx="100", pady="10", font="16", command=click_button9)
btn9.grid(column=0, row=1, columnspan=2, pady=16)

btn10 = Button(sub_panel, text="OpenBSC Console", background="#00C957", foreground="#000",
               padx="100", pady="10", font="16", command=click_button10)
btn10.grid(column=0, row=2, columnspan=2, pady=10)


root.mainloop()

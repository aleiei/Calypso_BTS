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
            msg = "Nessun subscriber trovato."
    except Exception as e:
        msg = f"Errore lettura DB:\n{e}"
    messagebox.showinfo(title='SUBSCRIBERS', message=msg)

def click_button8():
    subprocess.run(['sudo', 'rm', '-f', '/usr/src/CalypsoBTS/hlr.sqlite3'])
    messagebox.showinfo(title='RM DB', message='REMOVED')

def click_button9():
    db_path = '/usr/src/CalypsoBTS/hlr.sqlite3'
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT id, imsi, extension FROM Subscriber WHERE extension IS NOT NULL AND extension != '' AND extension != '111'")
        rows = cursor.fetchall()
        conn.close()
    except Exception as e:
        messagebox.showerror(title='Errore DB', message=str(e))
        return

    if not rows:
        messagebox.showwarning(title='SMS', message='Nessun subscriber con numero disponibile.')
        return

    win = Toplevel(root)
    win.title("Invia SMS")
    win.resizable(False, False)

    Label(win, text="Seleziona destinatari:", font=("Arial", 12, "bold")).pack(pady=8)

    frame_check = Frame(win, relief=SUNKEN, bd=1)
    frame_check.pack(padx=15, pady=4, fill=X)

    check_vars = []
    for r in rows:
        var = BooleanVar(value=True)
        check_vars.append(var)
        Checkbutton(frame_check,
                    text=f"Num: {r[2]}  |  IMSI: {r[1]}",
                    variable=var,
                    font=("Arial", 11), anchor=W).pack(fill=X, padx=8, pady=3)

    Label(win, text="Messaggio:", font=("Arial", 10)).pack(pady=(4, 2))
    msg_entry = Entry(win, width=42, font=("Arial", 11))
    msg_entry.insert(0, "SMS test")
    msg_entry.pack(padx=15)
    msg_entry.focus_set()

    def ensure_sms_sender_111():
        # Ensure sender extension 111 exists in HLR so VTY SMS command can use it.
        sender_imsi = "999999999999999"
        try:
            tn = telnetlib.Telnet("127.0.0.1", 4242, timeout=5)
            tn.read_until(b"OpenBSC", timeout=3)
            tn.write(f"subscriber create imsi {sender_imsi}\n".encode())
            tn.read_until(b"OpenBSC", timeout=3)
            tn.write(f"subscriber imsi {sender_imsi} extension 111\n".encode())
            tn.read_until(b"OpenBSC", timeout=3)
            tn.close()
            return True, ""
        except Exception as e:
            return False, str(e)

    def send(event=None):
        ok_sender, sender_err = ensure_sms_sender_111()
        if not ok_sender:
            messagebox.showerror(title='Errore SMS', message=f'Impossibile creare sender 111:\n{sender_err}')
            return

        selected = [(rows[i][0], rows[i][2]) for i, v in enumerate(check_vars) if v.get()]
        if not selected:
            messagebox.showwarning(title='SMS', message='Seleziona almeno un destinatario.')
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
                tn.read_until(b"OpenBSC> ")
                tn.close()
                sent.append(dest_ext)
            except Exception as e:
                errors.append(f"{dest_ext}: {e}")
        win.destroy()
        if sent:
            messagebox.showinfo(title='SMS', message=f'SMS inviato a: {", ".join(sent)}')
        if errors:
            messagebox.showerror(title='Errore SMS', message='\n'.join(errors))

    msg_entry.bind("<Return>", send)
    win.bind("<Return>", send)

    Button(win, text="Invia SMS", background="#FFD700", foreground="#000",
           padx=30, pady=8, font=("Arial", 12, "bold"), command=send).pack(pady=14)

def click_button_killall():
    procs = ['osmocon', 'transceiver', 'osmo-nitb', 'osmo-bts-trx']
    # termina i processi principali
    killed = []
    for p in procs:
        result = subprocess.run(['sudo', 'pkill', '-f', p])
        if result.returncode == 0:
            killed.append(p)
    # termina i terminali aperti che eseguono gli script CalypsoBTS
    scripts = ['trx.sh', 'trx2.sh', 'transceiver.sh', 'nitb.sh', 'osmobts.sh', 'console.sh']
    for s in scripts:
        subprocess.run(['sudo', 'pkill', '-f', s])
    # chiude solo i terminali aperti da questo script tramite PID
    for pid in terminal_pids:
        subprocess.run(['sudo', 'kill', str(pid)])
    terminal_pids.clear()
    if killed:
        messagebox.showinfo(title='Kill All', message='Terminati:\n' + '\n'.join(killed))
    else:
        messagebox.showinfo(title='Kill All', message='Nessun processo attivo trovato.')

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
root.resizable(False, False)

# ico add
img = PhotoImage(file='ico.png')
root.tk.call('wm', 'iconphoto', root._w, img)

# tab
tab_control = ttk.Notebook(root)
tab1 = ttk.Frame(tab_control)
tab2 = ttk.Frame(tab_control)
tab3 = ttk.Frame(tab_control)

tab_control.add(tab1, text='BTS')
tab_control.add(tab2, text='Subscribers')
tab_control.add(tab3, text='Help')

lbl1 = Label(tab1, text='')
lbl1.grid(column=0, row=0)

lbl2 = Label(tab2, text='')
lbl2.grid(column=0, row=0)

lbl3 = Label(tab3, text='\n                                         Simple Calypso BTS\n                                           Correct application launch sequence:\n                                           TXR1 (or TRX1 + TRX2) > Clock > DB > BTS \n                                          Alessandro Orlando (C) 2026 GPL V3')
lbl3.grid(column=0, row=0)

tab_control.pack(expand=1, fill='both')


btn13 = Button(tab1, text="TRX1", background="#B7B7B7", foreground="#000",
               padx="12", pady="10", font="16", command=click_button13)
btn13.place(x=160, y=150, anchor=CENTER)

btn = Button(tab1, text="TRX2", background="#B7B7B7", foreground="#000",
             padx="12", pady="10", font="16", command=click_button)
btn.place(x=240, y=150, anchor=CENTER)

btn2 = Button(tab1, text="Clock", background="#40E0D0", foreground="#000",
              padx="50", pady="10", font="16", command=click_button2)
btn2.place(x=400, y=150, anchor=CENTER)

btn3 = Button(tab1, text="DB", background="#B7B7B7", foreground="#000",
              padx="50", pady="10", font="16", command=click_button3)
btn3.place(x=200, y=250, anchor=CENTER)

btn4 = Button(tab1, text="! BTS !", background="#FF0000", foreground="#000",
              padx="50", pady="10", font="16", command=click_button4)
btn4.place(x=400, y=250, anchor=CENTER)

btn5 = Button(tab1, text="OpenBSC.cfg", background="#00C957", foreground="#000",
              padx="40", pady="10", font="16", command=click_button5)
btn5.place(x=200, y=50, anchor=CENTER)

btn6 = Button(tab1, text="OsmoBTS.cfg", background="#00C957", foreground="#000",
              padx="40", pady="10", font="16", command=click_button6)
btn6.place(x=400, y=50, anchor=CENTER)

btn7 = Button(tab2, text="Subscribers", background="#E066FF", foreground="#000",
              padx="40", pady="10", font="16", command=click_button7)
btn7.place(x=400, y=50, anchor=CENTER)

btn8 = Button(tab2, text="! Remove DB !", background="#1A1A1A", foreground="#FF0000",
              padx="40", pady="10", font="16", command=click_button8)
btn8.place(x=200, y=50, anchor=CENTER)

btn9 = Button(tab2, text="Test SMS", background="#FFD700", foreground="#000",
              padx="100", pady="10", font="16", command=click_button9)
btn9.place(x=300, y=150, anchor=CENTER)

btn10 = Button(tab2, text="OpenBSC Console", background="#00C957", foreground="#000",
               padx="100", pady="10", font="16", command=click_button10)
btn10.place(x=300, y=250, anchor=CENTER)

btn11 = Button(tab1, text="⚙", background="#40E0D0", foreground="#000",
               padx="8", pady="5", font="50", command=click_button11)
btn11.place(x=500, y=150, anchor=CENTER)

btn12 = Button(tab1, text="⚙", background="#B7B7B7", foreground="#000",
               padx="8", pady="5", font="50", command=click_button12)
btn12.place(x=100, y=150, anchor=CENTER)

btn14 = Button(tab1, text="⚙", background="#B7B7B7", foreground="#000",
               padx="8", pady="5", font="50", command=click_button14)
btn14.place(x=300, y=150, anchor=CENTER)

btn_kill = Button(tab1, text="⏹ Kill All", background="#8B0000", foreground="#FFFFFF",
                  padx="30", pady="10", font="16", command=click_button_killall)
btn_kill.place(x=300, y=310, anchor=CENTER)


root.mainloop()

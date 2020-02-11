/*
 * Send fake f5 key event, best suited for refreshing web page
 * while waiting for a release
 *
 * compile with
 * gcc f5.c -lX11 -lXtst -o f5
 *
 * Copyright (C) 2011, Onur Küçük <onur at delipenguen.net>
 *
*/


#include <X11/Xlib.h>
#include <X11/Intrinsic.h>
#include <X11/extensions/XTest.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>


int repeat = 10;
int sleepinterval = 2;


/* Send Fake Key Event */
static void sendKey (Display * disp, KeySym keysym, KeySym modsym) {
  KeyCode keycode = 0, modcode = 0;

  keycode = XKeysymToKeycode (disp, keysym);
  if (keycode == 0)
    return;

  XTestGrabControl (disp, True);

  /* Generate modkey press */
  if (modsym != 0) {
    modcode = XKeysymToKeycode(disp, modsym);
    XTestFakeKeyEvent (disp, modcode, True, 0);
  }

  /* Generate regular key press and release */
  XTestFakeKeyEvent (disp, keycode, True, 0);
  XTestFakeKeyEvent (disp, keycode, False, 0);

  /* Generate modkey release */
  if (modsym != 0)
    XTestFakeKeyEvent (disp, modcode, False, 0);

  XSync (disp, False);
  XTestGrabControl (disp, False);
}

void printusage(void) {
  printf("\n");
  printf("Automatic F5 pressing tool, start with \n");
  printf("\n");
  printf("f5 <repeat count> <delay in seconds> \n");
  printf("\n");
  printf("running as repeat=%d delay=%d\n", repeat, sleepinterval);
  printf("\n");
}


int main (int argc, char *argv[]) {

  Display *disp = XOpenDisplay (NULL);
  int i;

  if (argc > 1)
    repeat = atoi(argv[1]);

  if (argc > 2)
    sleepinterval = atoi(argv[2]);

  printusage();

  for (i = 0; i < repeat; i++) {
    sleep (sleepinterval);
    //SendKey (disp, XK_F5, XK_Alt_L);
    sendKey (disp, XK_F5, 0);
    printf("pressing f5\n");
  }

  printf("\n");
  return 0;

}



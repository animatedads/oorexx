#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <QApplication>
#include <QDialog>
#include <QPushButton>
#include <QLineEdit>
#include <QCoreApplication>
#include <QMetaObject>
#include <QPointer>
#include <QHash>
#include <QString>
#include <memory>
#include <QCheckBox>
#include <QAbstractButton>
#include <QComboBox>
#include <QLabel>
#include <QProgressBar>
#include <QSignalBlocker>

// All entrypoints and synchronous callbacks execute on the Qt GUI/Python owner thread.
// This module does not initialize an independent Python interpreter or launch processes.
namespace {
std::unique_ptr<QApplication> app;
int fakeArgc = 1;
char appName[] = "oodialog-qt";
char* fakeArgv[] = {appName, nullptr};
QPointer<QDialog> dialog;
QHash<int, QPointer<QWidget>> controls;
QHash<QString, PyObject*> callbacks;
PyObject* lastResult = nullptr;
QString key(int id, const QString& event) { return QString::number(id) + QLatin1Char(':') + event.toUpper(); }
unsigned long ownerThread = 0;

bool owner() {
  if (!app) {
    PyErr_SetString(PyExc_RuntimeError, "call open_dialog first");
    return false;
  }
  if (ownerThread != PyThread_get_thread_ident()) {
    PyErr_SetString(PyExc_RuntimeError, "Qt and Rexx callbacks must stay on the creating thread");
    return false;
  }
  return true;
}
void releaseCallbacks() {
  for (auto it = callbacks.begin(); it != callbacks.end(); ++it) Py_XDECREF(it.value());
  callbacks.clear();
  Py_CLEAR(lastResult);
}
void callListener(int id, const char* name) {
  PyObject* callback = callbacks.value(key(id, QString::fromLatin1(name)), nullptr);
  if (!callback) return;
  // A callback is synchronous and executed on the Python/Qt owner thread.
  Py_INCREF(callback); // Retain across reentrant listener replacement/removal.
  PyObject* result = PyObject_CallFunction(callback, "is", id, name);
  if (!result) {
    // GUI event callbacks cannot propagate through the Qt signal ABI.
    // Report through Python's unraisable hook rather than silently clearing it.
    PyErr_WriteUnraisable(callback);
    Py_DECREF(callback);
    return;
  }
  Py_XSETREF(lastResult, result); // Own the return for explicit inspection.
  Py_DECREF(callback);
}
PyObject* openDialog(PyObject*, PyObject* args) {
  const char* title = "ooDialog Linux";
  int width = 480, height = 320;
  if (!PyArg_ParseTuple(args, "|sii", &title, &width, &height)) return nullptr;
  if (!app) {
    if (QCoreApplication::instance()) {
      PyErr_SetString(PyExc_RuntimeError, "existing Qt application is not owned by this adapter");
      return nullptr;
    }
    app = std::make_unique<QApplication>(fakeArgc, fakeArgv);
    app->setQuitOnLastWindowClosed(false);
    ownerThread = PyThread_get_thread_ident();
  }
  if (width <= 0 || height <= 0) {PyErr_SetString(PyExc_ValueError, "dialog dimensions must be positive"); return nullptr;}
  if (!owner()) return nullptr;
  if (dialog) { PyErr_SetString(PyExc_RuntimeError, "dialog already open"); return nullptr; }
  dialog = new QDialog();
  dialog->setWindowTitle(QString::fromUtf8(title));
  dialog->resize(width, height);
  dialog->show();
  Py_RETURN_NONE;
}
PyObject* addButton(PyObject*, PyObject* args) {
  int id,x,y,w,h;
  const char* label;
  if (!PyArg_ParseTuple(args,"isiiii",&id,&label,&x,&y,&w,&h)) return nullptr;
  if (!owner() || !dialog) {if (!PyErr_Occurred()) PyErr_SetString(PyExc_RuntimeError,"no dialog");return nullptr;}
  if (controls.contains(id)) {PyErr_SetString(PyExc_ValueError,"duplicate control id");return nullptr;}
  auto* button = new QPushButton(QString::fromUtf8(label), dialog);
  button->setGeometry(x,y,w,h);
  controls.insert(id,button);
  QObject::connect(button,&QPushButton::clicked,dialog,[id] {callListener(id,"CLICKED");});
  Py_RETURN_NONE;
}
PyObject* addEdit(PyObject*, PyObject* args) {
  int id,x,y,w,h;
  const char* value;
  if (!PyArg_ParseTuple(args,"isiiii",&id,&value,&x,&y,&w,&h)) return nullptr;
  if (!owner() || !dialog) {if (!PyErr_Occurred()) PyErr_SetString(PyExc_RuntimeError,"no dialog");return nullptr;}
  if (controls.contains(id)) {PyErr_SetString(PyExc_ValueError,"duplicate control id");return nullptr;}
  auto* edit = new QLineEdit(QString::fromUtf8(value),dialog);
  edit->setGeometry(x,y,w,h);
  controls.insert(id,edit);
  QObject::connect(edit,&QLineEdit::textChanged,dialog,[id](const QString&) {callListener(id,"CHANGE");});
  Py_RETURN_NONE;
}
PyObject* bind(PyObject*, PyObject* args) {
  int id;
  const char* eventName;
  PyObject* listener;
  if (!PyArg_ParseTuple(args,"isO",&id,&eventName,&listener)) return nullptr;
  if (!owner()) return nullptr;
  if (!controls.contains(id)) {PyErr_SetString(PyExc_KeyError,"unknown control id");return nullptr;}
  const QString evt = QString::fromUtf8(eventName).toUpper();
  QWidget* target = controls.value(id).data();
  const bool supported =
      (qobject_cast<QPushButton*>(target) && evt == QLatin1String("CLICKED")) ||
      (qobject_cast<QLineEdit*>(target) && evt == QLatin1String("CHANGE")) ||
      (qobject_cast<QCheckBox*>(target) && evt == QLatin1String("CHANGE")) ||
      (qobject_cast<QComboBox*>(target) && evt == QLatin1String("SELCHANGE"));
  if (!supported) { PyErr_SetString(PyExc_ValueError,"event unsupported for this control type");return nullptr; }
  if (!PyCallable_Check(listener)) {PyErr_SetString(PyExc_TypeError,"listener must be callable");return nullptr;}
  Py_INCREF(listener);
  const QString eventKey = key(id, QString::fromUtf8(eventName));
  PyObject* previous = callbacks.value(eventKey,nullptr);
  callbacks.insert(eventKey,listener);
  Py_XDECREF(previous);
  Py_RETURN_NONE;
}
PyObject* unbind(PyObject*, PyObject* args) {
  int id;
  const char* eventName;
  if (!PyArg_ParseTuple(args, "is", &id, &eventName)) return nullptr;
  if (!owner()) return nullptr;
  const QString eventKey = key(id, QString::fromUtf8(eventName));
  auto it = callbacks.find(eventKey);
  if (it == callbacks.end()) Py_RETURN_FALSE;
  PyObject* previous = it.value();
  callbacks.erase(it);
  Py_DECREF(previous);
  Py_RETURN_TRUE;
}
PyObject* listenerCount(PyObject*, PyObject* args) {
  if (!PyArg_ParseTuple(args, "")) return nullptr;
  if (!owner()) return nullptr;
  return PyLong_FromSsize_t(callbacks.size());
}
PyObject* addCheckBox(PyObject*, PyObject* args) {
  int id,x,y,w,h;
  const char* text;
  if (!PyArg_ParseTuple(args,"isiiii",&id,&text,&x,&y,&w,&h)) return nullptr;
  if (!owner() || !dialog) {if (!PyErr_Occurred()) PyErr_SetString(PyExc_RuntimeError,"no dialog"); return nullptr;}
  if (controls.contains(id)) {PyErr_SetString(PyExc_ValueError,"duplicate control id"); return nullptr;}
  auto* widget = new QCheckBox(QString::fromUtf8(text),dialog);
  widget->setGeometry(x,y,w,h);
  controls.insert(id,widget);
  QObject::connect(widget,&QCheckBox::toggled,dialog,[id](bool) {callListener(id,"CHANGE");});
  Py_RETURN_NONE;
}
PyObject* addLabel(PyObject*, PyObject* args) {
  int id,x,y,w,h;
  const char* text;
  if (!PyArg_ParseTuple(args,"isiiii",&id,&text,&x,&y,&w,&h)) return nullptr;
  if (!owner() || !dialog) {if (!PyErr_Occurred()) PyErr_SetString(PyExc_RuntimeError,"no dialog"); return nullptr;}
  if (controls.contains(id)) {PyErr_SetString(PyExc_ValueError,"duplicate control id"); return nullptr;}
  auto* widget = new QLabel(QString::fromUtf8(text),dialog);
  widget->setGeometry(x,y,w,h);
  controls.insert(id,widget);
  Py_RETURN_NONE;
}
PyObject* addCombo(PyObject*, PyObject* args) {
  int id,x,y,w,h;
  if (!PyArg_ParseTuple(args,"iiiii",&id,&x,&y,&w,&h)) return nullptr;
  if (!owner() || !dialog) {if (!PyErr_Occurred()) PyErr_SetString(PyExc_RuntimeError,"no dialog"); return nullptr;}
  if (controls.contains(id)) {PyErr_SetString(PyExc_ValueError,"duplicate control id"); return nullptr;}
  auto* widget = new QComboBox(dialog);
  widget->setGeometry(x,y,w,h);
  controls.insert(id,widget);
  QObject::connect(widget,QOverload<int>::of(&QComboBox::currentIndexChanged),dialog,[id](int) {callListener(id,"SELCHANGE");});
  Py_RETURN_NONE;
}
PyObject* addItem(PyObject*, PyObject* args) {
  int id; const char* value;
  if (!PyArg_ParseTuple(args,"is",&id,&value)) return nullptr;
  if (!owner()) return nullptr;
  auto* combo=qobject_cast<QComboBox*>(controls.value(id,nullptr));
  if (!combo) {PyErr_SetString(PyExc_TypeError,"control is not a combo box");return nullptr;}
  combo->addItem(QString::fromUtf8(value));
  Py_RETURN_NONE;
}
PyObject* setText(PyObject*, PyObject* args) {
  int id; const char* value;
  if (!PyArg_ParseTuple(args,"is",&id,&value)) return nullptr;
  if (!owner()) return nullptr;
  auto* widget=controls.value(id,nullptr);
  if (auto* edit=qobject_cast<QLineEdit*>(widget)) edit->setText(QString::fromUtf8(value));
  else if (auto* label=qobject_cast<QLabel*>(widget)) label->setText(QString::fromUtf8(value));
  else if (auto* button=qobject_cast<QAbstractButton*>(widget)) button->setText(QString::fromUtf8(value));
  else {PyErr_SetString(PyExc_TypeError,"control does not support text");return nullptr;}
  Py_RETURN_NONE;
}
PyObject* getText(PyObject*, PyObject* args) {
  int id;
  if (!PyArg_ParseTuple(args,"i",&id)) return nullptr;
  if (!owner()) return nullptr;
  auto* widget=controls.value(id,nullptr);
  QString value;
  if (auto* edit=qobject_cast<QLineEdit*>(widget)) value=edit->text();
  else if (auto* label=qobject_cast<QLabel*>(widget)) value=label->text();
  else if (auto* button=qobject_cast<QAbstractButton*>(widget)) value=button->text();
  else {PyErr_SetString(PyExc_TypeError,"control does not support text");return nullptr;}
  return PyUnicode_FromString(value.toUtf8().constData());
}
PyObject* lastCallbackResult(PyObject*, PyObject* args) {
  if (!PyArg_ParseTuple(args,"")) return nullptr;
  if (!owner()) return nullptr;
  if (!lastResult) Py_RETURN_NONE;
  Py_INCREF(lastResult);
  return lastResult;
}
PyObject* activate(PyObject*, PyObject* args) {
  int id;
  if (!PyArg_ParseTuple(args,"i",&id)) return nullptr;
  if (!owner()) return nullptr;
  auto* button = qobject_cast<QPushButton*>(controls.value(id,nullptr));
  if (!button) {PyErr_SetString(PyExc_KeyError,"not a button");return nullptr;}
  Py_CLEAR(lastResult);
  button->click(); // synchronous Qt signal -> Python callable -> Rexx proxy
  if (PyErr_Occurred()) return nullptr;
  if (lastResult) { Py_INCREF(lastResult); return lastResult; }
  Py_RETURN_NONE;
}
PyObject* pump(PyObject*, PyObject* args) {
  if (!PyArg_ParseTuple(args,"")) return nullptr;
  if (!owner()) return nullptr;
  QCoreApplication::processEvents();
  Py_RETURN_NONE;
}
PyObject* closeDialog(PyObject*, PyObject* args) {
  if (!PyArg_ParseTuple(args,"")) return nullptr;
  if (!owner()) return nullptr;
  releaseCallbacks();
  controls.clear();
  if (dialog) {delete dialog.data();dialog = nullptr;}
  Py_RETURN_NONE;
}
PyMethodDef methods[] = {
  {"open_dialog",openDialog,METH_VARARGS,"Create and show a native Qt dialog on this thread."},
  {"add_button",addButton,METH_VARARGS,"Add button (id,text,x,y,width,height)."},
  {"add_edit",addEdit,METH_VARARGS,"Add edit (id,text,x,y,width,height)."},
  {"bind",bind,METH_VARARGS,"Bind listener(id, eventName, callable) to a control."},
  {"unbind",unbind,METH_VARARGS,"Remove an event listener; return whether one existed."},
  {"listener_count",listenerCount,METH_VARARGS,"Inspect registered listener count."},
  {"add_checkbox",addCheckBox,METH_VARARGS,"Add checkbox (id,text,x,y,width,height)."},
  {"add_label",addLabel,METH_VARARGS,"Add label (id,text,x,y,width,height)."},
  {"add_combo",addCombo,METH_VARARGS,"Add combo box (id,x,y,width,height)."},
  {"add_item",addItem,METH_VARARGS,"Add combo item (id,text)."},
  {"set_text",setText,METH_VARARGS,"Set supported widget text."},
  {"get_text",getText,METH_VARARGS,"Get supported widget text."},
  {"last_callback_result",lastCallbackResult,METH_VARARGS,"Return last successful callback value."},
  {"activate",activate,METH_VARARGS,"Click a button and dispatch its listener synchronously."},
  {"pump",pump,METH_VARARGS,"Process Qt GUI events on the owner thread."},
  {"close_dialog",closeDialog,METH_VARARGS,"Destroy dialog and release listener references."},
  {nullptr,nullptr,0,nullptr}
};
PyModuleDef module = {PyModuleDef_HEAD_INIT,"oodialog_qt","Qt6 listener extension for ooRexx/Python",-1,methods};
}
PyMODINIT_FUNC PyInit_oodialog_qt(void) {return PyModule_Create(&module);}
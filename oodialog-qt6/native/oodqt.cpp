/* oodqt.cpp -- the Qt6 renderer behind ooDialog's oodWeb.cls, on Linux.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 * Upstream ooDialog's Rexx classes run unchanged; oodWeb.cls (Claude
 * (Fable 5.2)) answers their native entry points and reaches a renderer
 * through one object with 15 messages.  In the browser that object is the
 * page runtime oodialog-web.js; here it is this library, reached from
 * Rexx through two routines of the ooRexx native API:
 *
 *   oodqt_call(name, payload) -> string   one renderer message
 *   oodqt_next(ms)            -> string   run Qt up to ms; one queued event or ""
 *
 * Fields are separated by 0x1F, records by 0x1E.  Events are
 * "key 1F kind 1F id 1F code 1F extra", the arguments oodWeb's pageEvent
 * takes.  Rexx is only ever called back through oodqt_next's return value,
 * so nothing re-enters the interpreter from a Qt signal.
 *
 * Behaviour follows oodialog-web.js where it defines it (dialog units,
 * subscriptions, ops, Win32 messages).  The steps player
 * (OODQT_STEPS=file) drives the same .steps files as the browser harness.
 */
#include <oorexxapi.h>

#include <QApplication>
#include <QButtonGroup>
#include <QCheckBox>
#include <QComboBox>
#include <QDateTimeEdit>
#include <QCalendarWidget>
#include <QTableView>
#include <QTextCharFormat>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QSlider>
#include <QStyledItemDelegate>
#include <QScrollBar>
#include <QPainter>
#include <QPainterPath>
#include <QImage>
#include <QPixmap>
#include <QPixmapCache>
#include <QIcon>
#include <QToolButton>
#include <QHBoxLayout>
#include <QVBoxLayout>
#include <QDialog>
#include <QDir>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QFontMetrics>
#include <QFrame>
#include <QGroupBox>
#include <QKeyEvent>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMenu>
#include <QMenuBar>
#include <QMessageBox>
#include <QMouseEvent>
#include <QPlainTextEdit>
#include <QProgressBar>
#include <QPushButton>
#include <QRadioButton>
#include <QRegularExpressionValidator>
#include <QScreen>
#include <QTextStream>
#include <QTabBar>
#include <QTreeWidget>
#include <QHeaderView>
#include <QCollator>
#include <QSet>
#include <QThread>
#include <QTimer>
#include <QVBoxLayout>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <condition_variable>
#include <deque>
#include <functional>
#include <algorithm>
#include <mutex>
#include <thread>
#include <map>
#include <memory>
#include <set>
#include <vector>

namespace {

const QChar FS(0x1F);
const QChar RS(0x1E);

/* List-view, tree-view and tab: data models that mirror oodialog-web.js's
 * (c.cols/c.rows, c.nodes/c.roots, c.tabs), with Qt widgets rendered from them. */
struct LvCol { QString text; double w = 50; QString fmt = "left"; };
struct LvRow { QStringList cells; bool sel = false, chk = false; int uid = 0; };
struct Lv {
    std::vector<LvCol> cols;
    std::vector<LvRow> rows;
    int focusIdx = -1, uid = 0, anchor = -1;
    bool single = false, dirty = false, rendering = false;
    QString view = "ICON";
    QSet<QString> ex;
    QTreeWidget *w = nullptr;
};
struct TvNode { int h = 0; QString text; int parent = 0; std::vector<int> kids; bool open = false, bold = false; };
struct Tv {
    std::map<int, TvNode> nodes;
    std::vector<int> roots;
    int nextH = 0, selH = 0;
    bool dirty = false, rendering = false;
    QTreeWidget *w = nullptr;
};
struct Mc;
struct TabC { QStringList tabs; int cur = -1; bool rendering = false; QTabBar *bar = nullptr; QWidget *box = nullptr; int minTab = -1; std::vector<int> raPages; };   // raPages: pagedTab's dialogs

struct Ctl {
    int id = 0;
    QString kind, opts, rawText;
    QWidget *el = nullptr;     // the placed widget
    QWidget *main = nullptr;   // the widget that takes input
    bool modified = false;
    int group = 0;
    std::shared_ptr<Lv> lv;
    std::shared_ptr<Tv> tv;
    std::shared_ptr<TabC> tab;
    std::shared_ptr<Mc> mc;                                       // a month calendar
    int lo = 0, hi = 100, pos = 0, page = 20, line = 1, buddy = 0;   // track bar and up-down
    bool buddyInt = false, wrap = false;
    QDateTime when;                                               // date-time picker: the part not shown is kept
    QString bmp;                                                  // a bitmap button's or image's key
    QString bmpDis;                                               // its disabled picture
    int parentCtl = 0;                                            // setParent: shown on, and placed in, this control
    QList<int> tabStops;                                          // a list box's tab stops, in pixels
    bool bmpStretch = false, bmpAt = false;                      // STRETCH; setBitmapPosition was used
    int bmpX = 0, bmpY = 0;
};

class OodDialog;

/* ResizingAdmin (oodResizableDialog.cpp), as oodialog-web.js v0.17.0 does it: each edge of each control is
 * pinned to an edge of the dialog or of another control.  type S stationary, P proportional, ML my left
 * (a right edge), MT my top (a bottom edge); edge LEFT TOP RIGHT BOTTOM XCENTER YCENTER; to 0 the dialog. */
struct RaEdge { QString type, edge; int to = 0; };
struct RaBox { double left = 0, top = 0, right = 0, bottom = 0; };
struct RaItem { int id = 0; QWidget *el = nullptr; RaEdge edges[4]; RaBox orig, cur; };
struct Ra {
    RaEdge def[4];
    std::vector<RaItem> items;    // the controls the program named first, in its order; then the others as created
    RaBox orig;                   // the client area when sizing began
    bool ended = false;           // wantSizeEnded: RASIZEENDED 250 ms after the last change
    bool watched = false;
};

struct Dlg {
    int key = 0;
    std::set<QString> mouseSubs;           // "id.NAME": the mouse events connected (Mouse~connectEvent)
    QString opts;
    OodDialog *win = nullptr;
    QWidget *client = nullptr;
    QMenuBar *menuBar = nullptr;
    std::map<int, Ctl> ctrls;
    std::vector<int> order;
    std::set<QString> subs;
    std::map<int, QButtonGroup *> radioGroups;
    std::map<int, QWidget *> gdi;          // the GDI layers: 0 the client area, else a control
    double fx = 1, fy = 1;
    int defId = 1, group = 0;
    bool shown = false, noClose = false;
    std::shared_ptr<Ra> ra;                // a ResizingAdmin dialog
    bool sizeWatched = false;
    std::map<int, std::shared_ptr<struct Tip>> tips;   // tool tips, by the tool tip's ID (60000 + id: a tree-view's own)
    std::set<int> infoTipTrees;            // tree-views that ask GETINFOTIP
};

std::map<int, Dlg *> dialogs;
std::map<QString, std::pair<QString, QPixmap>> images;   // name -> (data URL header, picture)
Qt::MouseButtons playerButtons;                         // the buttons the steps player holds down
std::deque<QString> events;           // guarded by eventsLock: a second Rexx thread may wait in oodqt_next
std::mutex eventsLock;
std::condition_variable eventsReady;
QEventLoop *waiting = nullptr;
QApplication *app = nullptr;

bool has(const QString &opts, const char *word) { return opts.contains(QLatin1String(word), Qt::CaseInsensitive); }

QString plain(const QString &text) {             // "&Name" -> "Name", "&&" -> "&"
    QString out;
    for (int i = 0; i < text.size(); ++i) {
        if (text[i] == '&' && i + 1 < text.size()) { out += text[++i]; continue; }
        out += text[i];
    }
    return out;
}

void fire(int key, const QString &kind, const QString &id, const QString &code, const QString &extra = QString()) {
    {
        std::lock_guard<std::mutex> g(eventsLock);
        events.push_back(QString::number(key) + FS + kind + FS + id + FS + code + FS + extra);
    }
    eventsReady.notify_all();

}

void cmd(Dlg *d, const Ctl &c, int code, bool always = false) {
    const QString id = QString::number(c.id), cs = QString::number(code);
    if (always || d->subs.count(id + "." + cs) || d->subs.count(id + ".*") || d->subs.count("*." + cs))
        fire(d->key, "CMD", id, cs);
}

QFont dialogFont(const QString &name, double size) {
    QFont f = QApplication::font();
    if (!name.isEmpty() && !name.startsWith("MS Shell Dlg", Qt::CaseInsensitive)
        && !name.startsWith("MS Sans Serif", Qt::CaseInsensitive) && name.compare("System", Qt::CaseInsensitive) != 0)
        f.setFamily(name);
    f.setPixelSize(std::max(1, (int)std::lround(size * 96.0 / 72.0)));
    return f;
}

/* Dialog base units, as Windows computes them from the dialog font (and as oodialog-web.js does). */
void baseUnits(const QFont &f, double &fx, double &fy) {
    QFontMetrics m(f);
    const double w = m.horizontalAdvance(QStringLiteral("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"));
    fx = std::floor((w / 26.0 + 1) / 2) / 4;
    fy = std::round((double)m.height()) / 8;
}

class OodDialog : public QDialog {
public:
    Dlg *d;
    explicit OodDialog(Dlg *dlg, QWidget *parent = nullptr) : QDialog(parent), d(dlg) {}
protected:
    void closeEvent(QCloseEvent *e) override {     // the close box is IDCANCEL; the Rexx side decides
        e->ignore();
        if (!d->noClose) fire(d->key, "CMD", "2", "0");
    }
    void keyPressEvent(QKeyEvent *e) override {
        if (e->key() == Qt::Key_Escape) { if (!d->noClose) fire(d->key, "CMD", "2", "0"); return; }
        if (e->key() == Qt::Key_F1) { fire(d->key, "CMD", "9", "0"); return; }
        if (e->key() == Qt::Key_Return || e->key() == Qt::Key_Enter) {
            QWidget *f = focusWidget();
            if (qobject_cast<QPlainTextEdit *>(f)) return;
            if (auto *b = qobject_cast<QPushButton *>(f)) { b->click(); return; }
            auto it = d->ctrls.find(d->defId);
            if (it != d->ctrls.end() && it->second.kind == "BUTTON") {
                if (it->second.main->isEnabled()) static_cast<QPushButton *>(it->second.main)->click();
            } else fire(d->key, "CMD", "1", "0");
            return;
        }
        QDialog::keyPressEvent(e);
    }
};

/* Qt key -> Windows virtual-key code, as the page's keyCode gives it. */
int virtualKey(int k) {
    if ((k >= Qt::Key_A && k <= Qt::Key_Z) || (k >= Qt::Key_0 && k <= Qt::Key_9)) return k;
    if (k >= Qt::Key_F1 && k <= Qt::Key_F24) return 112 + (k - Qt::Key_F1);
    switch (k) {
    case Qt::Key_Escape: return 27;  case Qt::Key_Return: case Qt::Key_Enter: return 13;
    case Qt::Key_Tab: case Qt::Key_Backtab: return 9;  case Qt::Key_Backspace: return 8;
    case Qt::Key_Space: return 32;   case Qt::Key_PageUp: return 33;  case Qt::Key_PageDown: return 34;
    case Qt::Key_End: return 35;     case Qt::Key_Home: return 36;    case Qt::Key_Left: return 37;
    case Qt::Key_Up: return 38;      case Qt::Key_Right: return 39;   case Qt::Key_Down: return 40;
    case Qt::Key_Insert: return 45;  case Qt::Key_Delete: return 46;
    case Qt::Key_Shift: return 16;   case Qt::Key_Control: return 17; case Qt::Key_Alt: return 18;
    }
    return 0;
}

/* Key presses anywhere in a dialog, as the page's capturing keydown listener sees them:
 * connectKeyPress must see keys typed into its child controls too. */
class KeyFilter : public QObject {
public:
    using QObject::QObject;
    bool eventFilter(QObject *obj, QEvent *e) override {
        if (e->type() != QEvent::KeyPress) return false;
        auto *w = qobject_cast<QWidget *>(obj);
        QWidget *first = QApplication::focusWidget();     // fire once: on the first delivery, not as it propagates to parents
        if (qEnvironmentVariableIsSet("OODQT_DEBUG")) fprintf(stderr, "oodqt: key %d to %s, focus %s\n", static_cast<QKeyEvent *>(e)->key(), obj->metaObject()->className(), first ? first->metaObject()->className() : "none");
        if (first ? w != first : (w && w != w->window())) return false;
        auto *d = w ? dynamic_cast<OodDialog *>(w->window()) : nullptr;
        if (!d || !d->d->subs.count("0.KEY")) return false;
        auto *k = static_cast<QKeyEvent *>(e);
        const int vk = virtualKey(k->key());
        if (!vk) return false;
        const QString mods = QString(k->modifiers() & Qt::ShiftModifier ? "S" : "") + (k->modifiers() & Qt::ControlModifier ? "C" : "")
                             + (k->modifiers() & Qt::AltModifier ? "A" : "");
        fire(d->d->key, "KEY", QString::number(vk), mods);
        return false;
    }
};

/* A static that reports clicks when it has the NOTIFY style. */
class ClickFilter : public QObject {
public:
    Dlg *d; int id;
    ClickFilter(Dlg *dlg, int cid, QObject *p) : QObject(p), d(dlg), id(cid) {}
    bool eventFilter(QObject *, QEvent *e) override {
        if (e->type() == QEvent::MouseButtonRelease) fire(d->key, "CMD", QString::number(id), "0");
        if (e->type() == QEvent::MouseButtonDblClick) fire(d->key, "CMD", QString::number(id), "1");
        return false;
    }
};

std::map<QString, QString> fields(const QString &record) {   // "k=v 1F k=v ..."
    std::map<QString, QString> out;
    for (const QString &f : record.split(FS)) {
        const int eq = f.indexOf('=');
        if (eq > 0) out[f.left(eq)] = f.mid(eq + 1);
    }
    return out;
}

void place(Dlg *d, QWidget *w, double x, double y, double cx, double cy) {
    w->setGeometry((int)std::lround(x * d->fx), (int)std::lround(y * d->fy), (int)std::lround(cx * d->fx), (int)std::lround(cy * d->fy));
}

/*---- list-view, tree-view, tab: behaviour as in oodialog-web.js ----*/
void note(Dlg *d, int id, const QString &ev, const QString &extra) {     // a WM_NOTIFY, if connected
    if (d->subs.count(QString::number(id) + "." + ev)) fire(d->key, "NOTIFY", QString::number(id), ev, extra);
}

void lvRender(Lv &L, double fx) {
    // In place: the rows Qt has are updated, not made anew, so a press that a render falls between and its
    // release still make a click (a rebuilt row is another row to Qt), and the view keeps its scroll position.
    L.rendering = true;
    QTreeWidget *w = L.w;
    while (w->topLevelItemCount() > (int)L.rows.size()) delete w->takeTopLevelItem(w->topLevelItemCount() - 1);
    const bool report = L.view == "REPORT";
    if (report) {
        w->setColumnCount(std::max<int>(1, (int)L.cols.size()));
        QStringList heads;
        for (const LvCol &c : L.cols) heads << c.text;
        w->setHeaderLabels(heads);
        for (size_t k = 0; k < L.cols.size(); ++k) w->setColumnWidth((int)k, (int)std::lround(L.cols[k].w * fx));
    } else w->setColumnCount(1);
    w->setHeaderHidden(!report);
    const bool checks = L.ex.contains("CHECKBOXES");
    for (size_t i = 0; i < L.rows.size(); ++i) {
        QTreeWidgetItem *item = (int)i < w->topLevelItemCount() ? w->topLevelItem((int)i) : new QTreeWidgetItem(w);
        const LvRow &r = L.rows[i];
        const int n = report ? std::max<int>(1, (int)L.cols.size()) : 1;
        for (int k = 0; k < n; ++k) { const QString t = k < r.cells.size() ? r.cells[k] : QString(); if (item->text(k) != t) item->setText(k, t); }
        if (checks) { if (item->checkState(0) != (r.chk ? Qt::Checked : Qt::Unchecked)) item->setCheckState(0, r.chk ? Qt::Checked : Qt::Unchecked); }
        else if (item->data(0, Qt::CheckStateRole).isValid()) item->setData(0, Qt::CheckStateRole, QVariant());
        if (item->isSelected() != r.sel) item->setSelected(r.sel);
    }
    if (L.focusIdx >= 0 && L.focusIdx < w->topLevelItemCount())
        w->selectionModel()->setCurrentIndex(w->model()->index(L.focusIdx, 0), QItemSelectionModel::NoUpdate);
    L.rendering = false;
}
void lvLater(std::shared_ptr<Lv> L, double fx) {
    if (L->dirty) return;
    L->dirty = true;
    QTimer::singleShot(0, L->w, [L, fx] { L->dirty = false; lvRender(*L, fx); });
}
void lvSel(Dlg *d, int id, std::shared_ptr<Lv> L, int i, bool on) {
    if (i < 0 || i >= (int)L->rows.size() || L->rows[i].sel == on) return;
    L->rows[i].sel = on;
    lvLater(L, d->fx);
    note(d, id, "SEL", QString::number(i) + FS + (on ? "SELECTED" : "UNSELECTED"));
}
void lvFocus(Dlg *d, int id, std::shared_ptr<Lv> L, int i) {
    if (L->focusIdx == i) return;
    const int old = L->focusIdx;
    L->focusIdx = i;
    lvLater(L, d->fx);
    if (old >= 0 && old < (int)L->rows.size()) note(d, id, "FOC", QString::number(old) + FS + "UNFOCUSED");
    if (i >= 0) note(d, id, "FOC", QString::number(i) + FS + "FOCUSED");
}
void lvPick(Dlg *d, int id, std::shared_ptr<Lv> L, int i, Qt::KeyboardModifiers m) {   // a click or key chooses row i
    const bool ctrl = m & Qt::ControlModifier, shift = m & Qt::ShiftModifier;
    const int n = (int)L->rows.size();
    if (i < 0) { for (int k = 0; k < n; ++k) lvSel(d, id, L, k, false); return; }
    if (L->single || (!ctrl && !shift)) {
        for (int k = 0; k < n; ++k) if (k != i) lvSel(d, id, L, k, false);
        lvSel(d, id, L, i, true);
        L->anchor = i;
    } else if (ctrl) { lvSel(d, id, L, i, !L->rows[i].sel); L->anchor = i; }
    else {
        const int a = L->anchor < 0 ? i : L->anchor, lo = std::min(a, i), hi = std::max(a, i);
        for (int k = 0; k < n; ++k) lvSel(d, id, L, k, k >= lo && k <= hi);
    }
    lvFocus(d, id, L, i);
}
QString keysOf(Qt::KeyboardModifiers m) {
    QStringList k;
    if (m & Qt::ShiftModifier) k << "SHIFT";
    if (m & Qt::ControlModifier) k << "CONTROL";
    if (m & Qt::AltModifier) k << "ALT";
    return k.isEmpty() ? "NONE" : k.join(' ');
}
bool syntheticMouse = false;                         // set by the steps player when it clicks an item
void lvWire(Dlg *d, int id, std::shared_ptr<Lv> L) {
    QTreeWidget *w = L->w;
    {                                                     // LVN_BEGINSCROLL when the view starts to move, LVN_ENDSCROLL when it rests 150 ms
        auto *rest = new QTimer(w); rest->setSingleShot(true); rest->setInterval(150);
        auto last = std::make_shared<QPoint>(0, 0), moved = std::make_shared<QPoint>(0, 0);
        auto scrolled = [d, id, w, L, rest, last, moved] {
            if (L->rendering) return;                     // rows the program puts in move nothing it should hear of
            const QPoint now(w->horizontalScrollBar()->value(), w->verticalScrollBar()->value());
            *moved = now - *last; *last = now;
            if (!rest->isActive()) note(d, id, "BEGINSCROLL", QString::number(moved->x()) + FS + QString::number(moved->y()));
            rest->start();
        };
        QObject::connect(rest, &QTimer::timeout, [d, id, moved] { note(d, id, "ENDSCROLL", QString::number(moved->x()) + FS + QString::number(moved->y())); });
        QObject::connect(w->verticalScrollBar(), &QScrollBar::valueChanged, scrolled);
        QObject::connect(w->horizontalScrollBar(), &QScrollBar::valueChanged, scrolled);
    }
    QObject::connect(w, &QTreeWidget::itemClicked, [d, id, L, w](QTreeWidgetItem *item, int col) {
        if (qEnvironmentVariableIsSet("OODQT_DEBUG")) fprintf(stderr, "oodqt: list-view %d itemClicked row %d col %d%s\n", id, w->indexOfTopLevelItem(item), col, L->rendering ? " (rendering)" : "");
        if (L->rendering) return;
        const int i = w->indexOfTopLevelItem(item);
        if (L->ex.contains("CHECKBOXES") && i >= 0 && (item->checkState(0) == Qt::Checked) != L->rows[i].chk) {
            L->rows[i].chk = item->checkState(0) == Qt::Checked;
            note(d, id, "CHECK", QString::number(i) + FS + (L->rows[i].chk ? "CHECKED" : "UNCHECKED"));
            return;
        }
        const auto m = QApplication::keyboardModifiers();
        lvPick(d, id, L, i, m);
        note(d, id, "CLICK", QString::number(i) + FS + QString::number(col) + FS + keysOf(m));
    });
    QObject::connect(w, &QTreeWidget::itemDoubleClicked, [d, id, L, w](QTreeWidgetItem *item, int col) {
        if (L->rendering) return;
        const int i = w->indexOfTopLevelItem(item);
        // the second click of a double click is a click too, as the page's (Qt reports only the double click)
        const auto mods = QApplication::keyboardModifiers();
        lvPick(d, id, L, i, mods);
        note(d, id, "CLICK", QString::number(i) + FS + QString::number(col) + FS + keysOf(mods));
        note(d, id, "DBLCLK", QString::number(i) + FS + QString::number(col) + FS + keysOf(QApplication::keyboardModifiers()));
        if (i >= 0) note(d, id, "ACTIVATE", QString::number(i));
    });
    QObject::connect(w->header(), &QHeaderView::sectionClicked, [d, id](int col) { note(d, id, "COLUMNCLICK", QString::number(col)); });
    QObject::connect(w, &QTreeWidget::currentItemChanged, [d, id, L, w](QTreeWidgetItem *cur, QTreeWidgetItem *prev) {
        // no previous row: Qt making a row current on focus, which Windows does not report
        if (L->rendering || syntheticMouse || !cur || !prev || QApplication::mouseButtons() != Qt::NoButton) return;     // keyboard moves only; clicks pick above
        lvPick(d, id, L, w->indexOfTopLevelItem(cur), QApplication::keyboardModifiers());
    });
}
int lvNext(const Lv &L, int start, const QString &flags) {
    const bool back = flags.contains("PREV");
    const int n = (int)L.rows.size();
    for (int i = start + (back ? -1 : 1); i >= 0 && i < n; i += back ? -1 : 1) {
        if (flags.contains("SELECTED") && !L.rows[i].sel) continue;
        if (flags.contains("FOCUSED") && i != L.focusIdx) continue;
        return i;
    }
    return -1;
}
QString lvOp(Dlg *d, int id, std::shared_ptr<Lv> L, const QString &name, const QString &a, const QString &b, const QString &c2) {
    const int i = a.toInt();
    auto &cols = L->cols;
    auto &rows = L->rows;
    const int nc = (int)cols.size(), nr = (int)rows.size();
    if (name == "insCol") {
        const QStringList p = b.split(FS);
        const int at = i < 0 || i > nc ? nc : i;
        cols.insert(cols.begin() + at, LvCol{p.value(0), p.value(1).toDouble(), p.value(2).isEmpty() ? "left" : p.value(2)});
        for (auto &r : rows) if (r.cells.size() > at) r.cells.insert(at, "");
        lvLater(L, d->fx); return QString::number(at);
    }
    if (name == "delCol") { if (i < 0 || i >= nc) return "0"; cols.erase(cols.begin() + i); for (auto &r : rows) if (i < r.cells.size()) r.cells.removeAt(i); lvLater(L, d->fx); return "1"; }
    if (name == "colCount") return QString::number(nc);
    if (name == "colInfo") return i >= 0 && i < nc ? cols[i].text + FS + QString::number(cols[i].w) + FS + cols[i].fmt : "";
    if (name == "setColWidth") { if (i < 0 || i >= nc) return "0"; cols[i].w = b.toDouble(); lvLater(L, d->fx); return "1"; }
    if (name == "insRow") {
        const int at = i < 0 || i > nr ? nr : i;
        LvRow r; r.cells = b.split(FS); r.uid = ++L->uid;
        rows.insert(rows.begin() + at, r);
        if (L->focusIdx >= at) L->focusIdx++;
        lvLater(L, d->fx); return QString::number(at);
    }
    if (name == "setCell") { if (i < 0 || i >= nr) return "0"; const int k = b.toInt(); while (rows[i].cells.size() <= k) rows[i].cells << ""; rows[i].cells[k] = c2; lvLater(L, d->fx); return "1"; }
    if (name == "cell") { const int k = b.toInt(); return i >= 0 && i < nr && k >= 0 && k < rows[i].cells.size() ? rows[i].cells[k] : ""; }
    if (name == "del") { if (i < 0 || i >= nr) return "0"; rows.erase(rows.begin() + i); if (L->focusIdx == i) L->focusIdx = -1; else if (L->focusIdx > i) L->focusIdx--; lvLater(L, d->fx); return "1"; }
    if (name == "clear") { rows.clear(); L->focusIdx = -1; lvLater(L, d->fx); return "1"; }
    if (name == "next") return QString::number(lvNext(*L, i, b));
    if (name == "state") {
        if (i < 0 || i >= nr) return "0";
        if (b == "SELECT") { if (L->single) for (int k = 0; k < nr; ++k) if (k != i) lvSel(d, id, L, k, false); lvSel(d, id, L, i, true); }
        else if (b == "DESELECT") lvSel(d, id, L, i, false);
        else lvFocus(d, id, L, i);
        return "1";
    }
    if (name == "itemState") { if (i < 0 || i >= nr) return ""; QStringList s; if (rows[i].sel) s << "SELECTED"; if (i == L->focusIdx) s << "FOCUSED"; return s.join(' '); }
    if (name == "deselAll") { for (int k = 0; k < nr; ++k) lvSel(d, id, L, k, false); return "1"; }
    if (name == "check") {
        for (int k = 0; k < nr; ++k) if ((i < 0 || k == i) && rows[k].chk != (b == "1")) {
            rows[k].chk = b == "1";
            note(d, id, "CHECK", QString::number(k) + FS + (rows[k].chk ? "CHECKED" : "UNCHECKED"));
        }
        lvLater(L, d->fx); return "1";
    }
    if (name == "isChecked") return i >= 0 && i < nr && rows[i].chk ? "1" : "0";
    if (name == "ex") {
        if (a == "GET") { QStringList all(L->ex.begin(), L->ex.end()); return all.join(' '); }
        for (const QString &w : b.split(' ', Qt::SkipEmptyParts)) { if (a == "ADD") L->ex.insert(w); else L->ex.remove(w); }
        lvLater(L, d->fx); return "1";
    }
    if (name == "find") {
        const QString t = a.toLower();
        const int start = b.toInt();
        const bool partial = c2.contains('P'), wrap = c2.contains('W');
        for (int k = 1; k <= nr; ++k) {
            int j = start + k;
            if (j >= nr) { if (!wrap) break; j -= nr; }
            const QString v = rows[j].cells.value(0).toLower();
            if (partial ? v.startsWith(t) : v == t) return QString::number(j);
        }
        return "-1";
    }
    if (name == "view") { if (a.isEmpty()) return L->view; L->view = a; lvLater(L, d->fx); return "1"; }
    if (name == "uid") return i >= 0 && i < nr ? QString::number(rows[i].uid) : "0";
    if (name == "rect") {                               // getItemRect / getSubitemRect: a row, or one cell, in the control's client area
        QTreeWidgetItem *it = L->w->topLevelItem(a.toInt());
        if (!it) return "";
        QRect r = L->w->visualItemRect(it);
        if (!b.isEmpty() && b.toInt() >= 0) {
            const int col = b.toInt();
            if (col >= L->w->columnCount()) return "";
            r.setLeft(L->w->columnViewportPosition(col)); r.setWidth(L->w->columnWidth(col));
        }
        const int f = L->w->frameWidth();
        r.translate(L->w->viewport()->mapTo(L->w, QPoint(0, 0)) - QPoint(f, f));
        return QString("%1 %2 %3 %4").arg(r.left()).arg(r.top()).arg(r.left() + r.width()).arg(r.top() + r.height());
    }
    if (name == "hit") {                                // the row and column at a point of the control: "row col", row -1 for none
        QPoint vp = L->w->viewport()->mapFrom(L->w, QPoint(a.toInt(), b.toInt()));
        QTreeWidgetItem *it = L->w->itemAt(vp);
        if (!it) return "-1 0";
        const int col = std::max(0, L->w->columnAt(vp.x()));
        return QString::number(L->w->indexOfTopLevelItem(it)) + " " + QString::number(col);
    }
    if (name == "sort") {
        const int col = i, dir = b == "D" ? -1 : 1;
        std::stable_sort(rows.begin(), rows.end(), [col, dir](const LvRow &x, const LvRow &y) {
            QCollator coll; coll.setNumericMode(true);
            return dir * coll.compare(x.cells.value(col), y.cells.value(col)) < 0;
        });
        L->focusIdx = -1; lvLater(L, d->fx); return "1";
    }
    fprintf(stderr, "oodqt: op not implemented yet: lv.%s\n", qPrintable(name));
    return "";
}

void tvRender(Tv &T) {
    T.rendering = true;
    QTreeWidget *w = T.w;
    w->clear();
    std::function<void(QTreeWidgetItem *, int)> add = [&](QTreeWidgetItem *parent, int h) {
        const TvNode &nd = T.nodes[h];
        auto *item = parent ? new QTreeWidgetItem(parent) : new QTreeWidgetItem(w);
        item->setText(0, nd.text);
        item->setData(0, Qt::UserRole, h);
        if (nd.bold) { QFont f = item->font(0); f.setBold(true); item->setFont(0, f); }
        for (int k : nd.kids) add(item, k);
        item->setExpanded(nd.open);
        if (h == T.selH) { w->setCurrentItem(item); item->setSelected(true); }
    };
    for (int h : T.roots) add(nullptr, h);
    T.rendering = false;
}
void tvLater(std::shared_ptr<Tv> T) {
    if (T->dirty) return;
    T->dirty = true;
    QTimer::singleShot(0, T->w, [T] { T->dirty = false; tvRender(*T); });
}
bool tvOpen(Dlg *d, int id, std::shared_ptr<Tv> T, int h, const QString &how) {
    auto it = T->nodes.find(h);
    if (it == T->nodes.end()) return false;
    const bool open = how == "TOGGLE" ? !it->second.open : how == "EXPAND";
    if (it->second.open == open) return true;
    note(d, id, "EXPANDING", QString::number(h) + FS + (open ? "EXPANDED" : "COLLAPSED"));
    it->second.open = open;
    tvLater(T);
    note(d, id, "EXPANDED", QString::number(h) + FS + (open ? "EXPANDED" : "COLLAPSED"));
    return true;
}
void tvSelect(Dlg *d, int id, std::shared_ptr<Tv> T, int h, const QString &action) {
    if (T->selH == h) return;
    const int old = T->selH;
    T->selH = h;
    tvLater(T);
    note(d, id, "SELCHANGED", QString::number(old) + FS + QString::number(h) + FS + action);
}
std::vector<int> tvVisible(Tv &T) {
    std::vector<int> out;
    std::function<void(const std::vector<int> &)> walk = [&](const std::vector<int> &l) {
        for (int h : l) { out.push_back(h); if (T.nodes[h].open) walk(T.nodes[h].kids); }
    };
    walk(T.roots);
    return out;
}
void tvDrop(Tv &T, int h) {
    auto it = T.nodes.find(h);
    if (it == T.nodes.end()) return;
    const std::vector<int> kids = it->second.kids;
    for (int k : kids) tvDrop(T, k);
    T.nodes.erase(h);
    if (T.selH == h) T.selH = 0;
}
void tvWire(Dlg *d, int id, std::shared_ptr<Tv> T) {
    QTreeWidget *w = T->w;
    QObject::connect(w, &QTreeWidget::currentItemChanged, [d, id, T](QTreeWidgetItem *cur, QTreeWidgetItem *) {
        if (T->rendering || !cur) return;
        const bool mouse = syntheticMouse || QApplication::mouseButtons() != Qt::NoButton;
        tvSelect(d, id, T, cur->data(0, Qt::UserRole).toInt(), mouse ? "MOUSE" : "KEYBOARD");
    });
    auto toggled = [d, id, T](QTreeWidgetItem *item, bool open) {
        if (T->rendering) return;
        tvOpen(d, id, T, item->data(0, Qt::UserRole).toInt(), open ? "EXPAND" : "COLLAPSE");
    };
    QObject::connect(w, &QTreeWidget::itemExpanded, [toggled](QTreeWidgetItem *i) { toggled(i, true); });
    QObject::connect(w, &QTreeWidget::itemCollapsed, [toggled](QTreeWidgetItem *i) { toggled(i, false); });
}
QString tvOp(Dlg *d, int id, std::shared_ptr<Tv> T, const QString &name, const QString &a, const QString &b, const QString &c2) {
    const int h = a.toInt();
    auto has = [&](int x) { return T->nodes.count(x) > 0; };
    auto sibs = [&](TvNode &x) -> std::vector<int> & { return x.parent ? T->nodes[x.parent].kids : T->roots; };
    if (name == "ins") {
        const QStringList p = c2.split(FS);
        const QString text = p.value(0), opts = p.value(1);
        const bool hasParent = has(h);
        const int nid = ++T->nextH;
        std::vector<int> &list = hasParent ? T->nodes[h].kids : T->roots;
        TvNode nd; nd.h = nid; nd.text = text; nd.parent = hasParent ? h : 0;
        nd.open = opts.contains("EXPANDED", Qt::CaseInsensitive); nd.bold = opts.contains("BOLD", Qt::CaseInsensitive);
        T->nodes[nid] = nd;
        if (b == "FIRST") list.insert(list.begin(), nid);
        else if (b == "SORT") { size_t k = 0; while (k < list.size() && QString::localeAwareCompare(T->nodes[list[k]].text, text) <= 0) ++k; list.insert(list.begin() + k, nid); }
        else if (b == "LAST" || b.isEmpty()) list.push_back(nid);
        else { auto at = std::find(list.begin(), list.end(), b.toInt()); if (at == list.end()) list.push_back(nid); else list.insert(at + 1, nid); }
        tvLater(T); return QString::number(nid);
    }
    if (name == "hit" || name == "rect") {              // v0.18.0: hitTestInfo and getItemRect, in the control's client area
        if (T->dirty) { T->dirty = false; tvRender(*T); }
        QTreeWidget *w = T->w;
        const int f = w->frameWidth();
        const QPoint vp = w->viewport()->mapTo(w, QPoint(0, 0)) - QPoint(f, f);   // the viewport in the client area
        auto textWidth = [&](QTreeWidgetItem *it) { return QFontMetrics(it->font(0)).horizontalAdvance(it->text(0)) + 6; };
        if (name == "hit") {
            const QPoint p = QPoint(a.toInt(), b.toInt()) - vp;
            QTreeWidgetItem *it = w->itemAt(p);
            if (!it) return "0 NOWHERE";
            const QRect cell = w->visualItemRect(it);
            QString where;
            if (p.x() >= cell.left() + textWidth(it)) where = "ONRIGHT";
            else if (p.x() >= cell.left()) where = "ONITEM ONLABEL";
            else if (p.x() >= cell.left() - w->indentation()) where = "ONBUTTON";
            else where = "ONINDENT";
            return QString::number(it->data(0, Qt::UserRole).toInt()) + " " + where;
        }
        for (QTreeWidgetItemIterator i(w); *i; ++i) {
            if ((*i)->data(0, Qt::UserRole).toInt() != h) continue;
            QRect r = w->visualItemRect(*i);
            if (r.isEmpty()) return "";                  // (the item is not shown)
            if (b == "1") r.setWidth(textWidth(*i));     // only its text
            else { r.setLeft(0); r.setWidth(w->viewport()->width()); }   // the whole row, as the page's row
            r.translate(vp);
            return QString("%1 %2 %3 %4").arg(r.left()).arg(r.top()).arg(r.left() + r.width()).arg(r.top() + r.height());
        }
        return "";
    }
    if (name == "del") { if (!has(h)) return "0"; auto &l = sibs(T->nodes[h]); l.erase(std::find(l.begin(), l.end(), h)); tvDrop(*T, h); tvLater(T); return "1"; }
    if (name == "clear") { T->nodes.clear(); T->roots.clear(); T->selH = 0; tvLater(T); return "1"; }
    if (name == "expand") return tvOpen(d, id, T, h, b) ? "1" : "0";
    if (name == "find") {
        const QString t = a.toLower();
        bool go = b.toInt() == 0;
        std::vector<int> all;
        std::function<void(const std::vector<int> &)> walk = [&](const std::vector<int> &l) { for (int x : l) { all.push_back(x); walk(T->nodes[x].kids); } };
        walk(T->roots);
        for (int x : all) {
            if (!go) { if (x == b.toInt()) go = true; continue; }
            const QString v = T->nodes[x].text.toLower();
            if (c2 == "1" ? v.startsWith(t) : v == t) return QString::number(x);
        }
        return "0";
    }
    if (name == "rel") {
        if (!has(h)) return "0";
        TvNode &nd = T->nodes[h];
        if (b == "CHILD") return QString::number(nd.kids.empty() ? 0 : nd.kids[0]);
        if (b == "PARENT") return QString::number(nd.parent);
        const std::vector<int> l = b.endsWith("VISIBLE") ? tvVisible(*T) : sibs(nd);
        auto at = std::find(l.begin(), l.end(), h);
        if (at == l.end()) return "0";
        if (b.startsWith("NEXT")) return QString::number(at + 1 == l.end() ? 0 : *(at + 1));
        return QString::number(at == l.begin() ? 0 : *(at - 1));
    }
    if (name == "special") return QString::number(a == "ROOT" || a == "FIRSTVISIBLE" ? (T->roots.empty() ? 0 : T->roots[0]) : a == "SELECTED" ? T->selH : 0);
    if (name == "info") {
        if (!has(h)) return "";
        TvNode &nd = T->nodes[h];
        QStringList s; if (nd.open) s << "EXPANDED"; if (nd.bold) s << "BOLD"; if (h == T->selH) s << "SELECTED";
        return nd.text + FS + QString::number(nd.kids.size()) + FS + s.join(' ');
    }
    if (name == "text") return has(h) ? T->nodes[h].text : "";
    if (name == "modify") {
        if (!has(h)) return "0";
        TvNode &nd = T->nodes[h];
        const QStringList p = b.split(FS);
        const QString flag = p.value(0), text = p.value(1), opts = p.value(2);
        if (flag.contains('T')) nd.text = text;
        if (flag.contains('O')) {
            if (opts.contains("NOTBOLD")) nd.bold = false; else if (opts.contains("BOLD")) nd.bold = true;
            if (opts.contains("EXPANDED")) nd.open = !opts.contains("NOTEXPANDED");
        }
        tvLater(T); return "1";
    }
    if (name == "select") {
        if (h != 0 && !has(h)) return "0";
        int p = h ? T->nodes[h].parent : 0;
        while (p) { T->nodes[p].open = true; p = T->nodes[p].parent; }
        tvSelect(d, id, T, h, "UNKNOWN");
        tvLater(T); return "1";
    }
    fprintf(stderr, "oodqt: op not implemented yet: tv.%s\n", qPrintable(name));
    return "";
}

/* A tab control: the strip along the top at its own height, the page frame below.  Placed by
 * hand, not by a layout: a short control (only the strip, as the designer makes it) keeps its strip. */
class TabBox : public QWidget {
public:
    QTabBar *bar = nullptr;
    QFrame *frame = nullptr;
    using QWidget::QWidget;
    void lay() {
        if (!bar || !frame) return;
        const int h = std::min(height(), bar->sizeHint().height());
        bar->setGeometry(0, 0, width(), h);
        frame->setGeometry(0, h, width(), std::max(0, height() - h));
    }
protected:
    void resizeEvent(QResizeEvent *) override { lay(); }
};

void tabRender(TabC &t) {
    t.rendering = true;
    while (t.bar->count()) t.bar->removeTab(0);
    for (const QString &s : t.tabs) t.bar->addTab(s);
    if (t.cur >= 0) t.bar->setCurrentIndex(t.cur);
    t.bar->setStyleSheet(t.minTab >= 0 ? QString("QTabBar::tab { min-width: %1px; }").arg(t.minTab) : QString());   // TCM_SETMINTABWIDTH
    t.rendering = false;
    if (auto *tb = dynamic_cast<TabBox *>(t.box)) tb->lay();
}
QString tabOp(Dlg *d, std::shared_ptr<TabC> t, const QString &name, const QString &a, const QString &b) {
    const int i = a.toInt(), n = t->tabs.size();
    if (name == "ins") {
        const int at = i < 0 || i > n ? n : i;
        t->tabs.insert(at, b);
        if (t->cur < 0) t->cur = 0; else if (at <= t->cur) t->cur++;
        tabRender(*t); return QString::number(at);
    }
    if (name == "text") return i >= 0 && i < n ? t->tabs[i] : "";
    if (name == "setText") { if (i < 0 || i >= n) return "0"; t->tabs[i] = b; tabRender(*t); return "1"; }
    if (name == "selectText") {
        const QString want = a.toLower();
        for (int k = 0; k < n; ++k) if (plain(t->tabs[k]).toLower() == want || t->tabs[k].toLower() == want) { t->cur = k; tabRender(*t); return QString::number(k); }
        return "-1";
    }
    if (name == "outer") { const QRect g = t->box->geometry(); return QString("%1 %2 %3 %4").arg(g.left()).arg(g.top()).arg(g.right() + 1).arg(g.bottom() + 1); }   // the whole control, in the client area
    if (name == "rect") {                                // the page area, relative to the dialog's client area
        const QRect g = t->box->geometry();
        const int top = g.top() + t->bar->sizeHint().height();
        return QString("%1 %2 %3 %4").arg(g.left() + 2).arg(top + 2).arg(g.right() + 1 - 2).arg(g.bottom() + 1 - 2);
    }
    Q_UNUSED(d);
    fprintf(stderr, "oodqt: op not implemented yet: tab.%s\n", qPrintable(name));
    return "";
}

/*---- date-time picker and up-down: the state the page keeps beside the widget ----*/
QString dtpGet(Ctl &c) {                                  // the part shown is the user's; the rest is kept
    auto *e = qobject_cast<QDateTimeEdit *>(c.main);
    if (e) {
        if (e->displayFormat().startsWith("HH")) c.when.setTime(e->time());
        else c.when.setDate(e->date());
    }
    return c.when.toString("yyyy-MM-ddTHH:mm:ss");
}
void dtpSet(Ctl &c, const QDateTime &t) {
    c.when = t;
    if (auto *e = qobject_cast<QDateTimeEdit *>(c.main)) { QSignalBlocker hush(e); e->setDateTime(t); }
}
void udSet(Dlg *d, Ctl &u, int pos) {
    u.pos = std::max(u.lo, std::min(u.hi, pos));
    auto b = d->ctrls.find(u.buddy);
    if (b == d->ctrls.end() || !u.buddyInt || b->second.kind != "EDIT") return;
    if (auto *e = qobject_cast<QLineEdit *>(b->second.main)) {
        QSignalBlocker hush(e);
        e->setText(QString::number(u.pos));
    }
    cmd(d, b->second, 0x400); cmd(d, b->second, 0x300);
}

/*---- month calendar (MONTHCALENDAR): behaviour as in oodialog-web.js v0.16.0 ----
 * A QCalendarWidget with a "Today:" line under it (NOTODAY leaves it out).  The days shown are 42 from
 * the first cell; Qt starts a month that begins on the first day of the week one row down, so the first
 * cell is the week before, and GETDAYSTATE and dayState count months from the month of that first cell.
 * Bold days are one bit mask a month (bit 0 is the 1st), as MCN_GETDAYSTATE has them. */
struct Mc {
    QCalendarWidget *cal = nullptr;
    QToolButton *foot = nullptr;
    QDate sel, today, min, max;
    std::map<int, quint32> bold;                    // year * 12 + month - 1 -> mask
    int firstDay = 0;                               // 0 Sunday ... 6 Saturday, as the page counts
    bool noToday = false, dayState = false, quiet = false;
    QDate shownMonth;                               // the first of the month shown
};
const char *MONTHS[] = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"};
QString mcIso(const QDate &d) { return d.toString("yyyy-MM-dd") + "T00:00:00"; }
QDate mcDate(const QString &v) { return QDate::fromString(v.trimmed().left(10), Qt::ISODate); }
QDate mcFirstShown(const Mc &m) {
    const QDate first = m.shownMonth;
    int col = (first.dayOfWeek() % 7 - m.firstDay + 7) % 7;   // dayOfWeek: Monday 1 .. Sunday 7
    if (col == 0) col = 7;                                    // Qt shows the week before a month that starts a row
    return first.addDays(-col);
}
void mcPaint(Mc &m) {
    QSignalBlocker hush(m.cal);
    m.cal->setDateTextFormat(QDate(), QTextCharFormat());
    const QDate f = mcFirstShown(m);
    for (int k = 0; k < 42; ++k) {
        const QDate d = f.addDays(k);
        auto it = m.bold.find(d.year() * 12 + d.month() - 1);
        if (it == m.bold.end() || !((it->second >> (d.day() - 1)) & 1)) continue;
        QTextCharFormat b; b.setFontWeight(QFont::Bold);
        m.cal->setDateTextFormat(d, b);
    }
    if (m.foot) { m.foot->setText("Today: " + QString("%1/%2/%3").arg(m.today.month()).arg(m.today.day()).arg(m.today.year())); m.foot->setVisible(!m.noToday); }
}
void mcShow(Dlg *d, int id, Mc &m, const QDate &day, bool ask) {    // bring the month of day into view; the program is asked for its bold days
    const QDate month(day.year(), day.month(), 1);
    const bool moved = month != m.shownMonth;
    m.shownMonth = month;
    m.quiet = true;
    m.cal->setCurrentPage(day.year(), day.month());
    m.quiet = false;
    mcPaint(m);
    if (moved && ask && m.dayState) {
        const QDate f = mcFirstShown(m);
        note(d, id, "GETDAYSTATE", mcIso(QDate(f.year(), f.month(), 1)) + FS + "3");
    }
}
void mcPick(Dlg *d, int id, Mc &m, const QDate &day, bool byUser) {
    if (!day.isValid() || (m.min.isValid() && day < m.min) || (m.max.isValid() && day > m.max)) return;
    m.sel = day;
    { QSignalBlocker hush(m.cal); m.cal->setSelectedDate(day); }
    mcShow(d, id, m, day, byUser);
    if (byUser) { const QString e = mcIso(day) + FS + mcIso(day); note(d, id, "SELCHANGE", e); note(d, id, "SELECT", e); }
}
void mcBold(Mc &m, const QDate &from, const QString &masks) {
    int k = 0;
    for (const QString &v : masks.split(' ', Qt::SkipEmptyParts)) {
        const QDate d = from.addMonths(k++);
        m.bold[d.year() * 12 + d.month() - 1] = (quint32)v.toLongLong();
    }
    mcPaint(m);
}
QString mcOp(Dlg *d, int id, Mc &m, const QString &name, const QString &a, const QString &b) {
    if (name == "get") return mcIso(m.sel);
    if (name == "set") { const QDate v = mcDate(a); if (!v.isValid()) return "0"; m.sel = v; { QSignalBlocker hush(m.cal); m.cal->setSelectedDate(v); } mcShow(d, id, m, v, false); return "1"; }
    if (name == "today") { if (!a.isEmpty()) { m.today = mcDate(a); mcPaint(m); } return mcIso(m.today); }
    if (name == "range") {
        m.min = mcDate(a); m.max = mcDate(b);
        { QSignalBlocker hush(m.cal); m.cal->setDateRange(m.min.isValid() ? m.min : QDate(1601, 1, 1), m.max.isValid() ? m.max : QDate(9999, 12, 31)); }
        if (m.min.isValid() && m.sel < m.min) m.sel = m.min;
        if (m.max.isValid() && m.sel > m.max) m.sel = m.max;
        { QSignalBlocker hush(m.cal); m.cal->setSelectedDate(m.sel); }
        mcShow(d, id, m, m.sel, false);
        return "1";
    }
    if (name == "getRange") return (m.min.isValid() ? mcIso(m.min) : QString()) + FS + (m.max.isValid() ? mcIso(m.max) : QString());
    if (name == "months") {                                  // P: with the days of the months before and after; else the whole month
        if (a != "P") return mcIso(m.shownMonth) + FS + mcIso(m.shownMonth.addMonths(1).addDays(-1)) + FS + "1";
        const QDate f = mcFirstShown(m), l = f.addDays(41);
        return mcIso(f) + FS + mcIso(l) + FS + QString::number((l.year() - f.year()) * 12 + l.month() - f.month() + 1);
    }
    if (name == "dayState") { const QDate f = mcFirstShown(m); mcBold(m, QDate(f.year(), f.month(), 1), a); return "1"; }
    if (name == "dayStateFrom") { const QDate f = mcDate(a); if (!f.isValid()) return "0"; mcBold(m, QDate(f.year(), f.month(), 1), b); return "1"; }
    if (name == "firstDay") {                                // Windows: 0 is Monday
        if (!a.isEmpty()) {
            m.firstDay = (a.toInt() + 1) % 7;
            QSignalBlocker hush(m.cal);
            m.cal->setFirstDayOfWeek(Qt::DayOfWeek(m.firstDay == 0 ? 7 : m.firstDay));
            mcPaint(m);
        }
        return QString::number((m.firstDay + 6) % 7);
    }
    if (name == "minRect") { const QSize s = m.cal->parentWidget()->minimumSizeHint().expandedTo(m.cal->parentWidget()->sizeHint()); return QString::number(s.width()) + " " + QString::number(s.height()); }
    if (name == "todayWidth") return m.noToday ? "0" : QString::number(QFontMetrics(m.foot->font()).horizontalAdvance(m.foot->text()) + 12);
    if (name == "hit") {                                     // what is at a point of the client area
        QWidget *box = m.cal->parentWidget();
        QWidget *t = box->childAt(a.toInt(), b.toInt());
        if (!t) return "NOWHERE";
        if (t == m.foot) return "TODAY";
        if (t->objectName() == "qt_calendar_prevmonth") return "PREV";
        if (t->objectName() == "qt_calendar_nextmonth") return "NEXT";
        auto *view = m.cal->findChild<QTableView *>("qt_calendar_calendarview");
        if (view && (t == view->viewport() || view->isAncestorOf(t))) {
            const QModelIndex i = view->indexAt(view->viewport()->mapFrom(box, QPoint(a.toInt(), b.toInt())));
            const int row = i.row() - 1, col = i.column() - (m.cal->verticalHeaderFormat() == QCalendarWidget::NoVerticalHeader ? 0 : 1);
            if (!i.isValid() || row < 0 || col < 0) return "NOWHERE";
            return "DATE " + mcIso(mcFirstShown(m).addDays(row * 7 + col));
        }
        if (t->objectName().startsWith("qt_calendar")) return "TITLE";
        return "NOWHERE";
    }
    return "";
}

/* A list-view does not select rows by dragging over them: on Windows a drag with the button down is
 * LVN_BEGINDRAG, for the program; the selection stays.  Moves still reach the mouse layer (the
 * application's filter sees them first). */
class NoDragSelect : public QObject {
public:
    using QObject::QObject;
    bool eventFilter(QObject *, QEvent *e) override {
        return e->type() == QEvent::MouseMove && (static_cast<QMouseEvent *>(e)->buttons() & Qt::LeftButton);
    }
};

/* An editable combo box selects the whole of its edit's text when it takes the focus, as Windows does. */
class SelectOnFocus : public QObject {
public:
    using QObject::QObject;
    bool eventFilter(QObject *o, QEvent *e) override {
        if (e->type() == QEvent::FocusIn) if (auto *cb = qobject_cast<QComboBox *>(o)) if (cb->lineEdit()) QTimer::singleShot(0, cb->lineEdit(), &QLineEdit::selectAll);
        return false;
    }
};

/*---- tool tips: behaviour as in oodialog-web.js v0.18.0 ----
 * A ToolTip is not a control: it is a set of tools kept by its dialog under the tool tip's ID, and one
 * floating box for the whole process.  A tool is a control (host its ID), the dialog's client area (host 0),
 * or a rectangle of either; its text is fixed, or asked each time with NEEDTEXT.  The pointer resting on a
 * tool for the delay makes the tip due.  Events go to Rexx as TT ttId SHOW|POP|NEEDTEXT toolKey, and
 * RELAY toolKey SEP x SEP y for a tool the program manages.  A tree-view asks GETINFOTIP for its items. */
struct TipTool { QString key; int host = 0; bool hasRect = false; QRect rect; bool hasText = false; QString text; bool relay = false; };
struct Tip {
    int id = 0;
    std::vector<TipTool> tools;
    int delay = 500, maxWidth = 0;
    QString title, events;
    bool active = true;
    std::set<int> hosts, relayHosts;
    std::map<int, QString> current;                 // host -> the key of the tool the pointer is on
    std::map<int, QTimer *> timers;                 // host -> its delay timer (each window has its own)
    int rearmHost = -1;
};
struct TipBox {
    QFrame *el = nullptr; QLabel *title = nullptr, *body = nullptr;
    Dlg *d = nullptr; int tt = 0; QString tool; bool shown = false;
    QPoint at;                                      // the pointer, in screen pixels
} tipBox;
QFrame *tipEl() {
    if (!tipBox.el) {
        tipBox.el = new QFrame(nullptr, Qt::ToolTip | Qt::FramelessWindowHint | Qt::WindowTransparentForInput);   // as a Windows tip, it takes no input
        tipBox.el->setAttribute(Qt::WA_TransparentForMouseEvents);
        tipBox.el->setAttribute(Qt::WA_ShowWithoutActivating);
        tipBox.el->setObjectName("ood-tip");
        tipBox.el->setStyleSheet("#ood-tip{background:#fff;color:#333;border:1px solid #767676;border-radius:3px}");
        auto *lay = new QVBoxLayout(tipBox.el); lay->setContentsMargins(7, 3, 7, 3); lay->setSpacing(2);
        tipBox.title = new QLabel(tipBox.el); QFont f = tipBox.title->font(); f.setBold(true); tipBox.title->setFont(f);
        tipBox.body = new QLabel(tipBox.el); tipBox.body->setTextFormat(Qt::PlainText);
        lay->addWidget(tipBox.title); lay->addWidget(tipBox.body);
    }
    return tipBox.el;
}
bool tipHas(const Tip &t, const char *event) { return t.events.split(' ', Qt::SkipEmptyParts).contains(event); }
void tipHide(bool silent) {
    if (tipBox.shown) {
        tipBox.shown = false; tipEl()->hide();
        if (!silent && tipBox.d && dialogs.count(tipBox.d->key) && tipBox.d->tips.count(tipBox.tt) && tipHas(*tipBox.d->tips[tipBox.tt], "POP"))
            fire(tipBox.d->key, "TT", QString::number(tipBox.tt), "POP", tipBox.tool);
    }
    tipBox.tool.clear();
}
void tipDisplay(Dlg *d, Tip &tt, const QString &tool, const QString &text) {
    if (text.isEmpty() || !tt.active) return;
    QFrame *el = tipEl();
    tipBox.title->setText(tt.title); tipBox.title->setVisible(!tt.title.isEmpty());
    tipBox.body->setText(text);
    tipBox.body->setWordWrap(tt.maxWidth > 0);
    tipBox.body->setMaximumWidth(tt.maxWidth > 0 ? tt.maxWidth : QWIDGETSIZE_MAX);
    el->adjustSize();
    QRect screen = QGuiApplication::primaryScreen() ? QGuiApplication::primaryScreen()->availableGeometry() : QRect(0, 0, 4096, 4096);
    if (QScreen *s = QGuiApplication::screenAt(tipBox.at)) screen = s->availableGeometry();
    el->move(std::min(tipBox.at.x() + 12, screen.right() - el->width() - 4), std::min(tipBox.at.y() + 20, screen.bottom() - el->height() - 4));
    el->show(); el->raise();
    tipBox.shown = true; tipBox.d = d; tipBox.tt = tt.id; tipBox.tool = tool;
    if (tipHas(tt, "SHOW")) fire(d->key, "TT", QString::number(tt.id), "SHOW", tool);
}
void tipDue(Dlg *d, Tip &tt, const TipTool &tool) {
    tipBox.d = d; tipBox.tt = tt.id; tipBox.tool = tool.key;
    if (tool.hasText) tipDisplay(d, tt, tool.key, tool.text);
    else fire(d->key, "TT", QString::number(tt.id), "NEEDTEXT", tool.key);
}
void tipTrackAll(Dlg *d) {                          // the pointer's moves must reach Qt with no button down
    d->win->setMouseTracking(true);
    for (QWidget *w : d->win->findChildren<QWidget *>()) w->setMouseTracking(true);
}
void tipLeave(Dlg *d, Tip &tt, int host) {
    if (auto t = tt.timers.find(host); t != tt.timers.end()) t->second->stop();
    const QString cur = tt.current[host];
    if (!cur.isEmpty() && tipBox.d == d && tipBox.tt == tt.id && tipBox.tool == cur) tipHide(false);
    tt.current[host].clear();
    if (tt.rearmHost == host) tt.rearmHost = -1;
}
void tipArm(Dlg *d, Tip &tt, int host, const QString &key) {
    QTimer *&tm = tt.timers[host];
    if (!tm) { tm = new QTimer(d->win); tm->setSingleShot(true); }
    tm->disconnect();
    const int dk = d->key, ttId = tt.id;
    QObject::connect(tm, &QTimer::timeout, [dk, ttId, host, key] {
        if (!dialogs.count(dk)) return;
        Dlg *dd = dialogs[dk];
        if (!dd->tips.count(ttId)) return;
        Tip &t = *dd->tips[ttId];
        if (t.current[host] != key) return;
        for (const TipTool &tool : t.tools) if (tool.key == key) { tipDue(dd, t, tool); return; }
    });
    tm->start(tt.delay);
}
/* The host a widget belongs to: the innermost control of its dialog that holds it; 0 the client area
 * itself (or a part of it that is no control); -1 not in the client area (the frame, another window). */
int tipHostOf(Dlg *d, QWidget *w, QWidget **hostWidget) {
    if (!w || !(w == d->client || d->client->isAncestorOf(w))) return -1;
    int best = 0; QWidget *bw = d->client;
    for (auto &kv : d->ctrls) {
        QWidget *el = kv.second.el;
        if (!el || !(el == w || el->isAncestorOf(w))) continue;
        if (bw == d->client || bw->isAncestorOf(el)) { best = kv.first; bw = el; }
    }
    *hostWidget = bw;
    return best;
}
void tipTreeMove(Dlg *d, int id, QPoint global);
class TipWatch : public QObject {
public:
    using QObject::QObject;
    Dlg *last = nullptr; int lastTreeH = 0;
    void leaveAll(Dlg *d) {
        if (!d || !dialogs.count(d->key)) return;
        for (auto &kv : d->tips) for (int h : std::set<int>(kv.second->hosts)) tipLeave(d, *kv.second, h);
        tipTreeMove(d, 0, QPoint());
    }
    bool eventFilter(QObject *o, QEvent *e) override {
        const QEvent::Type t = e->type();
        if (t != QEvent::MouseMove && t != QEvent::MouseButtonPress && t != QEvent::Leave) return false;
        auto *w = qobject_cast<QWidget *>(o);
        if (!w) return false;
        Dlg *d = nullptr;
        for (auto &kv : dialogs) if (kv.second->win && kv.second->win == w->window()) d = kv.second;
        // the pointer left the window, unless a crossing came from the tip box appearing (it takes no input) while the pointer is still in
        if (t == QEvent::Leave) { if (d && w == d->win && !d->win->frameGeometry().contains(QCursor::pos())) leaveAll(d); return false; }
        {                                                 // Qt passes an event no one takes on to the parents: only the widget under the pointer counts
            auto *me = static_cast<QMouseEvent *>(e);
            static quint64 lastStamp = 0; static int lastType = 0; static QPointF lastGlobal;
            if (me->timestamp() == lastStamp && (int)t == lastType && me->globalPosition() == lastGlobal) return false;
            lastStamp = me->timestamp(); lastType = (int)t; lastGlobal = me->globalPosition();
        }
        if (last && last != d) leaveAll(last);
        last = d;
        if (!d || (d->tips.empty() && d->infoTipTrees.empty())) return false;
        const QPoint g = static_cast<QMouseEvent *>(e)->globalPosition().toPoint();
        QWidget *hw = nullptr;
        const int host = tipHostOf(d, w, &hw);
        if (t == QEvent::MouseButtonPress) {             // a press ends the tip of the window pressed, and its wait
            for (auto &kv : d->tips) {
                Tip &tt = *kv.second;
                if (auto tm = tt.timers.find(host); tm != tt.timers.end()) tm->second->stop();
                if (!tt.current[host].isEmpty() && tipBox.tt == tt.id && tipBox.tool == tt.current[host]) tipHide(false);
            }
            tipTreeMove(d, 0, QPoint());
            return false;
        }
        tipBox.at = g;
        tipTreeMove(d, d->infoTipTrees.count(host) ? host : 0, g);
        for (auto &kv : d->tips) {
            Tip &tt = *kv.second;
            for (int h : std::set<int>(tt.hosts)) if (h != host) tipLeave(d, tt, h);
            if (host < 0 || !tt.hosts.count(host)) continue;
            QWidget *hostW = host ? d->ctrls[host].el : d->client;
            const QPoint p = hostW->mapFromGlobal(g);
            const TipTool *tool = nullptr;
            for (const TipTool &x : tt.tools) if (x.host == host && (!x.hasRect || (p.x() >= x.rect.left() && p.x() < x.rect.right() && p.y() >= x.rect.top() && p.y() < x.rect.bottom()))) { tool = &x; break; }
            if (tool && (tool->relay || tt.relayHosts.count(host))) fire(d->key, "TT", QString::number(tt.id), "RELAY", tool->key + FS + QString::number(p.x()) + FS + QString::number(p.y()));
            const QString key = tool ? tool->key : QString();
            if (key == tt.current[host]) continue;
            tipLeave(d, tt, host);
            tt.current[host] = key;
            if (tool && tt.active) { tipArm(d, tt, host, key); tt.rearmHost = host; }
        }
        return false;
    }
};
TipWatch *tipWatch = nullptr;
struct TreeTipState { Dlg *d = nullptr; int id = 0, h = 0; QTimer *timer = nullptr; } treeTip;
void tipTreeMove(Dlg *d, int id, QPoint global) {    // a tree-view's own tips: GETINFOTIP for the item under the pointer
    int h = 0;
    if (id && d->ctrls.count(id) && d->ctrls[id].tv) {
        QTreeWidget *tw = d->ctrls[id].tv->w;
        if (QTreeWidgetItem *it = tw->itemAt(tw->viewport()->mapFromGlobal(global))) h = it->data(0, Qt::UserRole).toInt();
    }
    if (treeTip.d == d && treeTip.id == id && treeTip.h == h) return;
    if (treeTip.timer) treeTip.timer->stop();
    if (tipBox.shown && tipBox.d == treeTip.d && tipBox.tool == "tv" + QString::number(treeTip.id)) tipHide(false);
    treeTip.d = d; treeTip.id = id; treeTip.h = h;
    if (!h || !d->subs.count(QString::number(id) + ".GETINFOTIP")) return;
    if (!treeTip.timer) { treeTip.timer = new QTimer(); treeTip.timer->setSingleShot(true); }
    treeTip.timer->disconnect();
    const int dk = d->key, ttId = 60000 + id;
    QObject::connect(treeTip.timer, &QTimer::timeout, [dk, id, h, ttId] {
        if (!dialogs.count(dk) || treeTip.h != h || treeTip.id != id) return;
        Dlg *dd = dialogs[dk];
        tipBox.d = dd; tipBox.tt = ttId; tipBox.tool = "tv" + QString::number(id);
        note(dd, id, "GETINFOTIP", QString::number(h));
    });
    const int delay = d->tips.count(ttId) ? d->tips[ttId]->delay : 500;
    treeTip.timer->start(delay);
}
Tip &tipSet(Dlg *d, int ttId) {
    auto &t = d->tips[ttId];
    if (!t) { t = std::make_shared<Tip>(); t->id = ttId; }
    if (!tipWatch) { tipWatch = new TipWatch(qApp); qApp->installEventFilter(tipWatch); }
    return *t;
}
QString tipOp(Dlg *d, int ttId, const QString &name, const QString &a, const QString &b) {
    Tip &tt = tipSet(d, ttId);
    if (name == "add") {
        const QJsonObject o = QJsonDocument::fromJson(a.toUtf8()).object();
        TipTool t;
        t.key = o["key"].toString(); t.host = o["host"].toInt();
        if (o["rect"].isArray()) { const QJsonArray r = o["rect"].toArray(); t.hasRect = true; t.rect = QRect(QPoint(r[0].toInt(), r[1].toInt()), QPoint(r[2].toInt() - 1, r[3].toInt() - 1)); }
        if (o["text"].isString()) { t.hasText = true; t.text = o["text"].toString(); }
        tt.tools.erase(std::remove_if(tt.tools.begin(), tt.tools.end(), [&](const TipTool &x) { return x.key == t.key; }), tt.tools.end());
        tt.tools.push_back(t);
        tt.hosts.insert(t.host);
        if (t.host && d->ctrls.count(t.host)) { QWidget *el = d->ctrls[t.host].el; el->setToolTip(QString()); if (d->ctrls[t.host].main) d->ctrls[t.host].main->setToolTip(QString()); }
        tipTrackAll(d);
        return "1";
    }
    if (name == "del") { tt.tools.erase(std::remove_if(tt.tools.begin(), tt.tools.end(), [&](const TipTool &x) { return x.key == a; }), tt.tools.end()); return "1"; }
    if (name == "text") {
        for (TipTool &x : tt.tools) if (x.key == a) { x.hasText = b != FS; x.text = x.hasText ? b : QString(); return "1"; }
        return "0";
    }
    if (name == "relay") { if (b == "1") tt.relayHosts.insert(a.toInt()); else tt.relayHosts.erase(a.toInt()); return "1"; }
    if (name == "count") return QString::number(tt.tools.size());
    if (name == "delay") { tt.delay = std::max(0, a.toInt()); return "1"; }
    if (name == "maxWidth") { const int old = tt.maxWidth; tt.maxWidth = a.toInt(); return QString::number(old ? old : -1); }
    if (name == "title") { tt.title = a; return "1"; }
    if (name == "active") { tt.active = a == "1"; if (!tt.active && tipBox.tt == tt.id && tipBox.d == d) tipHide(false); return "1"; }
    if (name == "events") { tt.events = a; return "1"; }
    if (name == "show") { if (tipBox.d == d && tipBox.tt == tt.id && !tipBox.tool.isEmpty()) tipDisplay(d, tt, tipBox.tool, a); return "1"; }   // the answer to NEEDTEXT or GETINFOTIP
    if (name == "pos") { tipEl()->move(a.toInt(), b.toInt()); return "1"; }                                                                    // screen pixels
    if (name == "pop") {
        if (tipBox.d == d && tipBox.tt == tt.id) tipHide(false);
        if (tt.rearmHost >= 0) { const QString cur = tt.current[tt.rearmHost]; if (!cur.isEmpty() && tt.active) tipArm(d, tt, tt.rearmHost, cur); }   // still on the tool: due again
        return "1";
    }
    if (name == "shown") return tipBox.shown && tipBox.d == d && tipBox.tt == tt.id ? tipBox.tool + FS + (tipBox.title->isVisible() ? tipBox.title->text() : QString()) + tipBox.body->text() : QString();
    if (name == "tree") { const int id = a.toInt(); if (!d->ctrls.count(id)) return "0"; d->infoTipTrees.insert(id); tipTrackAll(d); return "1"; }
    return "";
}

void addControl(Dlg *d, const std::map<QString, QString> &s) {
    auto get = [&](const char *k) { auto it = s.find(k); return it == s.end() ? QString() : it->second; };
    Ctl c;
    c.id = get("id").toInt();
    c.kind = get("kind").toUpper();
    c.opts = get("opts").toUpper();
    const QString text = get("text");
    c.rawText = text;
    if (has(c.opts, "GROUP")) d->group++;
    c.group = d->group;
    QWidget *parent = d->client;
    const int id = c.id;
    if (c.kind == "BUTTON") {
        auto *b = new QPushButton(text, parent);
        b->setAutoDefault(false);
        if (has(c.opts, "DEFAULT")) { b->setDefault(true); d->defId = id; }
        QObject::connect(b, &QPushButton::clicked, [d, id] { cmd(d, d->ctrls[id], 0, true); });
        c.el = c.main = b;
    } else if (c.kind == "CHECK" || c.kind == "RADIO") {
        QAbstractButton *b;
        if (c.kind == "RADIO") {
            b = new QRadioButton(text, parent);
            b->setAutoExclusive(false);
            auto &g = d->radioGroups[c.group];
            if (!g) { g = new QButtonGroup(d->client); g->setExclusive(true); }
            g->addButton(b);
        } else {
            auto *cb = new QCheckBox(text, parent);
            if (has(c.opts, "3STATE")) cb->setTristate(true);
            b = cb;
        }
        if (has(c.opts, "LTEXT")) b->setLayoutDirection(Qt::RightToLeft);
        QObject::connect(b, &QAbstractButton::clicked, [d, id] { cmd(d, d->ctrls[id], 0, true); });
        c.el = c.main = b;
    } else if (c.kind == "GROUP") {
        auto *g = new QGroupBox(plain(text), parent);
        c.el = c.main = g;
    } else if (c.kind == "STATIC") {
        auto *l = new QLabel(plain(text), parent);
        l->setWordWrap(true);
        Qt::Alignment a = Qt::AlignLeft;
        if (has(c.opts, "CENTER")) a = Qt::AlignHCenter; else if (has(c.opts, "RIGHT")) a = Qt::AlignRight;
        l->setAlignment(a | Qt::AlignTop);
        if (has(c.opts, "BORDER")) l->setFrameStyle(QFrame::Box | QFrame::Plain);
        if (has(c.opts, "NOTIFY")) l->installEventFilter(new ClickFilter(d, id, l));
        c.el = c.main = l;
    } else if (c.kind == "FRAME") {
        auto *f = new QFrame(parent);
        f->setFrameStyle((has(c.opts, "RECT") ? QFrame::Panel : QFrame::Box) | (has(c.opts, "ETCHED") ? QFrame::Sunken : QFrame::Plain));
        if (has(c.opts, "RECT")) {
            f->setAutoFillBackground(true);
            QPalette p = f->palette();
            p.setColor(QPalette::Window, has(c.opts, "WHITE") ? Qt::white : has(c.opts, "GRAY") ? QColor(160, 160, 160) : Qt::black);
            f->setPalette(p);
        }
        c.el = c.main = f;
    } else if (c.kind == "EDIT") {
        if (has(c.opts, "MULTILINE")) {
            auto *t = new QPlainTextEdit(text, parent);
            t->setReadOnly(has(c.opts, "READONLY"));
            QObject::connect(t, &QPlainTextEdit::textChanged, [d, id] { cmd(d, d->ctrls[id], 0x400); cmd(d, d->ctrls[id], 0x300); });
            c.el = c.main = t;
        } else {
            auto *e = new QLineEdit(text, parent);
            if (has(c.opts, "PASSWORD")) e->setEchoMode(QLineEdit::Password);
            e->setReadOnly(has(c.opts, "READONLY"));
            if (has(c.opts, "NUMBER")) e->setValidator(new QRegularExpressionValidator(QRegularExpression("[0-9]*"), e));
            if (has(c.opts, "CENTER")) e->setAlignment(Qt::AlignHCenter); else if (has(c.opts, "RIGHT")) e->setAlignment(Qt::AlignRight);
            if (has(c.opts, "NOBORDER")) e->setFrame(false);
            const bool up = has(c.opts, "UPPER"), low = has(c.opts, "LOWER");
            QObject::connect(e, &QLineEdit::textEdited, [d, id, e, up, low](const QString &t) {
                if (up && t != t.toUpper()) e->setText(t.toUpper());
                if (low && t != t.toLower()) e->setText(t.toLower());
                d->ctrls[id].modified = true;
            });
            QObject::connect(e, &QLineEdit::textChanged, [d, id] { cmd(d, d->ctrls[id], 0x400); cmd(d, d->ctrls[id], 0x300); });
            QObject::connect(e, &QLineEdit::editingFinished, [d, id] { cmd(d, d->ctrls[id], 0x200); });
            c.el = c.main = e;
        }
    } else if (c.kind == "LIST") {
        auto *l = new QListWidget(parent);
        if (has(c.opts, "MULTI")) l->setSelectionMode(has(c.opts, "EXTSEL") ? QAbstractItemView::ExtendedSelection : QAbstractItemView::MultiSelection);
        if (has(c.opts, "SORT")) l->setSortingEnabled(true);
        QObject::connect(l, &QListWidget::currentRowChanged, [d, id] { cmd(d, d->ctrls[id], 1); });
        QObject::connect(l, &QListWidget::itemDoubleClicked, [d, id] { cmd(d, d->ctrls[id], 2); });
        c.el = c.main = l;
    } else if (c.kind == "COMBO") {
        auto *b = new QComboBox(parent);
        const bool droplist = has(c.opts, "LIST") && !has(c.opts, "SIMPLE");
        b->setEditable(!droplist);
        if (has(c.opts, "SORT")) b->setInsertPolicy(QComboBox::InsertAlphabetically);
        if (!droplist) {
            b->setInsertPolicy(QComboBox::NoInsert);     // Enter in the edit adds no item, as on Windows
            b->installEventFilter(new SelectOnFocus(b));  // and taking the focus selects the edit's text
        }
        QObject::connect(b, QOverload<int>::of(&QComboBox::activated), [d, id] { cmd(d, d->ctrls[id], 9); cmd(d, d->ctrls[id], 1); });
        if (!droplist) QObject::connect(b, &QComboBox::editTextChanged, [d, id] { cmd(d, d->ctrls[id], 6); cmd(d, d->ctrls[id], 5); });
        c.el = c.main = b;
    } else if (c.kind == "PROGRESS") {
        auto *p = new QProgressBar(parent);
        p->setRange(0, 100);
        p->setTextVisible(false);
        if (has(c.opts, "VERTICAL")) p->setOrientation(Qt::Vertical);
        c.el = c.main = p;
    } else if (c.kind == "LISTVIEW") {
        auto L = std::make_shared<Lv>();
        L->single = has(c.opts, "SINGLESEL");
        L->view = has(c.opts, "REPORT") ? "REPORT" : has(c.opts, "SMALLICON") ? "SMALLICON" : has(c.opts, "LIST") ? "LIST" : "ICON";
        L->w = new QTreeWidget(parent);
        L->w->setObjectName("ood-lv");
        L->w->setRootIsDecorated(false);
        L->w->setSelectionMode(L->single ? QAbstractItemView::SingleSelection : QAbstractItemView::ExtendedSelection);
        c.lv = L;
        {                                                 // the page's geometry: rows a line and 2 px, the header a line and 5 px
            const int line = QFontMetrics(d->win->font()).height();
            L->w->setUniformRowHeights(true);
            L->w->setStyleSheet(QString("QTreeView::item { height: %1px; padding: 0px 6px; } QHeaderView::section { padding: 2px 6px; }").arg(line + 2));
            L->w->header()->setFixedHeight(line + 5);
            L->w->viewport()->installEventFilter(new NoDragSelect(L->w));
        }
        lvWire(d, id, L);
        lvRender(*L, d->fx);
        c.el = c.main = L->w;
    } else if (c.kind == "TREEVIEW") {
        auto T = std::make_shared<Tv>();
        T->w = new QTreeWidget(parent);
        T->w->setObjectName("ood-tv");
        T->w->setHeaderHidden(true);
        c.tv = T;
        tvWire(d, id, T);
        c.el = c.main = T->w;
    } else if (c.kind == "TAB") {
        auto t = std::make_shared<TabC>();
        auto *tb = new TabBox(parent);
        t->box = tb;
        t->box->setObjectName("ood-tab");
        t->bar = new QTabBar(t->box);
        t->bar->setObjectName("ood-tabstrip");
        t->bar->setExpanding(false);
        auto *frame = new QFrame(t->box);
        frame->setFrameStyle(QFrame::StyledPanel | QFrame::Raised);
        tb->bar = t->bar; tb->frame = frame;
        QObject::connect(t->bar, &QTabBar::currentChanged, [d, id, t](int i) {
            if (t->rendering || i < 0) return;
            note(d, id, "SELCHANGING", "");
            t->cur = i;
            note(d, id, "SELCHANGE", "");
        });
        c.tab = t;
        c.el = c.main = t->box;
    } else if (c.kind == "IMAGE") {                      // createStaticImage: a bitmap or icon
        auto *l = new QLabel(parent);
        l->setObjectName("ood-image");
        if (has(c.opts, "CENTERIMAGE")) l->setAlignment(Qt::AlignCenter); else l->setAlignment(Qt::AlignLeft | Qt::AlignTop);
        if (has(c.opts, "SUNKEN") || has(c.opts, "BORDER")) l->setFrameStyle(QFrame::Box | QFrame::Plain);
        c.el = c.main = l;
    } else if (c.kind == "TRACKBAR") {
        auto *s = new QSlider(has(c.opts, "VERTICAL") ? Qt::Vertical : Qt::Horizontal, parent);
        s->setRange(0, 100); s->setPageStep(20); s->setSingleStep(1);
        if (has(c.opts, "AUTOTICKS")) s->setTickPosition(has(c.opts, "VERTICAL") ? QSlider::TicksRight : QSlider::TicksBelow);
        if (has(c.opts, "VERTICAL")) s->setInvertedAppearance(true);
        QObject::connect(s, &QSlider::sliderMoved, [d, id](int v) { note(d, id, "TRACK", QString::number(v) + FS + "DRAG"); });
        QObject::connect(s, &QSlider::actionTriggered, [d, id, s](int action) {
            if (action == QAbstractSlider::SliderMove) return;          // a drag: sliderReleased gives its ENDTRACK
            QTimer::singleShot(0, s, [d, id, s] { if (!s->isSliderDown()) note(d, id, "TRACK", QString::number(s->value()) + FS + "ENDTRACK"); });
        });
        QObject::connect(s, &QSlider::sliderReleased, [d, id, s] { note(d, id, "TRACK", QString::number(s->value()) + FS + "ENDTRACK"); });
        c.el = c.main = s;
    } else if (c.kind == "DATETIMEPICKER") {
        auto *e = new QDateTimeEdit(parent);
        e->setObjectName("ood-dtp");
        const bool time = has(c.opts, "TIME");
        e->setDisplayFormat(time ? "HH:mm:ss" : "yyyy-MM-dd");
        e->setCalendarPopup(!time && !has(c.opts, "UPDOWN"));
        c.when = QDateTime::currentDateTime();
        e->setDateTime(c.when);
        QObject::connect(e, &QDateTimeEdit::dateTimeChanged, [d, id] { note(d, id, "DATETIMECHANGE", dtpGet(d->ctrls[id])); });
        c.el = c.main = e;
    } else if (c.kind == "MONTHCALENDAR") {
        auto *box = new QWidget(parent);
        box->setObjectName("ood-mc");
        box->setAutoFillBackground(true);
        auto *lay = new QVBoxLayout(box); lay->setContentsMargins(0, 0, 0, 0); lay->setSpacing(0);
        auto m = std::make_shared<Mc>();
        m->cal = new QCalendarWidget(box);
        m->cal->setGridVisible(false);
        m->cal->setHorizontalHeaderFormat(QCalendarWidget::ShortDayNames);
        m->cal->setVerticalHeaderFormat(has(c.opts, "WEEKNUMBERS") ? QCalendarWidget::ISOWeekNumbers : QCalendarWidget::NoVerticalHeader);
        m->cal->setFirstDayOfWeek(Qt::Sunday);
        m->foot = new QToolButton(box);
        m->foot->setObjectName("ood-mc-foot");
        m->foot->setAutoRaise(true);
        m->foot->setFocusPolicy(Qt::NoFocus);
        lay->addWidget(m->cal, 1);
        lay->addWidget(m->foot, 0, Qt::AlignLeft);
        m->noToday = has(c.opts, "NOTODAY");
        m->dayState = has(c.opts, "DAYSTATE");
        m->today = m->sel = QDate::currentDate();
        m->shownMonth = QDate(m->sel.year(), m->sel.month(), 1);
        m->cal->setSelectedDate(m->sel);
        mcPaint(*m);
        Mc *mp = m.get();
        QObject::connect(m->cal, &QCalendarWidget::clicked, [d, id, mp](QDate day) { mcPick(d, id, *mp, day, true); });
        QObject::connect(m->cal, &QCalendarWidget::activated, [d, id, mp](QDate day) { if (day != mp->sel) mcPick(d, id, *mp, day, true); });
        QObject::connect(m->cal, &QCalendarWidget::currentPageChanged, [d, id, mp](int y, int mo) {   // the user moved a month
            if (mp->quiet) return;
            mcShow(d, id, *mp, QDate(y, mo, 1), true);
        });
        QObject::connect(m->foot, &QToolButton::clicked, [d, id, mp] { mcPick(d, id, *mp, mp->today, true); });
        c.mc = m;
        c.el = box;
        c.main = m->cal;
    } else if (c.kind == "UPDOWN") {
        auto *box = new QWidget(parent);
        box->setObjectName("ood-ud");
        auto *lay = new QVBoxLayout(box); lay->setContentsMargins(0, 0, 0, 0); lay->setSpacing(0);
        auto *up = new QToolButton(box), *dn = new QToolButton(box);
        up->setArrowType(Qt::UpArrow); dn->setArrowType(Qt::DownArrow);
        for (auto *b : {up, dn}) { b->setFocusPolicy(Qt::NoFocus); b->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Expanding); lay->addWidget(b); }
        if (has(c.opts, "AUTOBUDDY") && !d->order.empty()) c.buddy = d->order.back();
        c.buddyInt = has(c.opts, "BUDDYINT"); c.wrap = has(c.opts, "WRAP");
        auto step = [d, id](int by) {
            Ctl &u = d->ctrls[id];
            int np = u.pos + by;
            if (np > u.hi) np = u.wrap ? u.lo : u.hi;
            if (np < u.lo) np = u.wrap ? u.hi : u.lo;
            note(d, id, "DELTAPOS", QString::number(u.pos) + FS + QString::number(np - u.pos));
            udSet(d, u, np);
        };
        QObject::connect(up, &QToolButton::clicked, [step] { step(1); });
        QObject::connect(dn, &QToolButton::clicked, [step] { step(-1); });
        c.el = c.main = box;
    } else {                                              // not yet: shown as a labelled placeholder, as the page does
        auto *l = new QLabel(c.kind + " (not yet)", parent);
        l->setObjectName("ood-todo");
        l->setFrameStyle(QFrame::Box | QFrame::Plain);
        c.el = c.main = l;
    }
    place(d, c.el, get("x").toDouble(), get("y").toDouble(), get("cx").toDouble(), get("cy").toDouble());
    if (c.kind == "COMBO") c.el->resize(c.el->width(), qRound(12 * d->fy));   // cy is the dropped height; the box itself is one line, as the page draws it
    if (c.kind == "UPDOWN" && c.buddy && (has(c.opts, "RIGHT") || has(c.opts, "LEFT"))) {   // sits inside its buddy's edge
        auto b = d->ctrls.find(c.buddy);
        if (b != d->ctrls.end()) {
            const QRect r = b->second.el->geometry();
            const int w = qRound(9 * d->fx);
            c.el->setGeometry(has(c.opts, "RIGHT") ? r.right() - w : r.left() + 1, r.top() + 1, w, r.height() - 2);
        }
    }
    if (c.kind == "TAB") c.el->lower();                  // the pages' controls are its siblings, drawn over it
    if (has(c.opts, "HIDDEN")) c.el->hide(); else c.el->show();
    if (has(c.opts, "DISABLED")) c.main->setEnabled(false);
    if (has(c.opts, "NOTAB")) c.main->setFocusPolicy(Qt::ClickFocus);
    if (c.kind == "STATIC" || c.kind == "GROUP" || c.kind == "FRAME") c.main->setFocusPolicy(Qt::NoFocus);
    d->ctrls[id] = c;
    d->order.push_back(id);
}

Dlg *dialog(const QString &key) {
    auto it = dialogs.find(key.toInt());
    return it == dialogs.end() ? nullptr : it->second;
}

/*---- menus: records "depth 1F id 1F text 1F flags", joined by 1E ----*/
void buildMenu(Dlg *d, QMenuBar *bar, const QString &data) {
    std::vector<QMenu *> path;
    std::vector<QStringList> recs;
    for (const QString &r : data.split(RS, Qt::SkipEmptyParts)) recs.push_back(r.split(FS));
    for (size_t i = 0; i < recs.size(); ++i) {
        const QStringList &r = recs[i];
        if (r.size() < 3) continue;
        const int depth = r[0].toInt(), id = r[1].toInt();
        const QString text = r[2], flags = " " + (r.size() > 3 ? r[3] : QString()) + " ";
        const bool popup = i + 1 < recs.size() && recs[i + 1][0].toInt() > depth;
        path.resize(depth);
        QWidget *owner = depth == 0 ? (QWidget *)bar : (QWidget *)path[depth - 1];
        if (!owner) continue;
        if (flags.contains(" SEPARATOR ")) {
            if (depth > 0) path[depth - 1]->addSeparator();
            continue;
        }
        if (popup) {
            QMenu *m = depth == 0 ? bar->addMenu(text) : path[depth - 1]->addMenu(text);
            path.push_back(m);
            continue;
        }
        QAction *a = depth == 0 ? bar->addAction(text) : path[depth - 1]->addAction(text);
        a->setEnabled(!flags.contains(" GRAYED ") && !flags.contains(" DISABLED "));
        if (flags.contains(" CHECKED ")) { a->setCheckable(true); a->setChecked(true); }
        const int key = d->key;
        QObject::connect(a, &QAction::triggered, [key, id] { fire(key, "CMD", QString::number(id), "0"); });
    }
}

/* A dialog with a sizing border (THICKFRAME): the client area reports WM_SIZE as RESIZE (width SEP height)
 * when connectResize asked, and SIZEMOVEENDED 250 ms after the last change, as the page does. */
/* A bitmap button's picture for its state: stretched over the button, drawn from the top left at
 * setBitmapPosition's offset (a sprite sheet moved under the button, as oowalker animates it), or centred. */
void bmpPaint(Ctl &c) {
    auto *b = qobject_cast<QPushButton *>(c.main);
    auto it = images.find(c.bmp);
    if (!b || it == images.end()) return;
    auto picture = [&](const QPixmap &src) {
        if (!c.bmpAt) return src;
        QPixmap out(b->size());
        out.fill(Qt::transparent);
        QPainter p(&out);
        p.drawPixmap(c.bmpX, c.bmpY, src);
        return out;
    };
    QIcon icon(picture(it->second.second));
    if (auto dis = images.find(c.bmpDis); dis != images.end()) icon.addPixmap(picture(dis->second.second), QIcon::Disabled);
    b->setIcon(icon);
    b->setIconSize(c.bmpStretch || c.bmpAt ? b->size() : it->second.second.size());
}

void raLayout(Dlg *d);

class SizeWatch : public QObject {
public:
    Dlg *d;
    QSize start;
    QTimer ended;
    SizeWatch(Dlg *dd, QSize s, QObject *parent) : QObject(parent), d(dd), start(s) {
        d->sizeWatched = true;
        ended.setSingleShot(true);
        ended.setInterval(250);
        QObject::connect(&ended, &QTimer::timeout, [this] {
            if (d->subs.count("0.SIZEMOVEENDED")) fire(d->key, "WM", "0", "SIZEMOVEENDED");
            if (d->ra && d->ra->ended) fire(d->key, "WM", "0", "RASIZEENDED");
        });
    }
    bool eventFilter(QObject *o, QEvent *e) override {
        if (e->type() != QEvent::Resize) return false;
        auto *c = static_cast<QWidget *>(o);
        if (d->ra) raLayout(d);                          // ResizingAdmin: the controls follow the dialog
        if (c->size() == start) return false;            // being shown at its own size is no change
        start = QSize();                                  // from now on, every change counts
        if (d->subs.count("0.RESIZE")) fire(d->key, "WM", "0", "RESIZE", QString::number(c->width()) + FS + QString::number(c->height()));
        ended.start();
        return false;
    }
};

RaBox raRect(QWidget *el) { const QRect g = el->geometry(); return {(double)g.left(), (double)g.top(), (double)g.left() + g.width(), (double)g.top() + g.height()}; }
RaEdge raEdge(const QJsonValue &v) { const QJsonArray a = v.toArray(); return {a[0].toString(), a[1].toString(), a[2].toInt()}; }
void raLimits(Dlg *d, const QJsonValue &min, const QJsonValue &max) {   // "initial": the size the dialog had; null: none
    QWidget *cl = d->client;
    QSize lo(60, 30), hi(QWIDGETSIZE_MAX, QWIDGETSIZE_MAX);
    if (min.isString() && min.toString() == "initial") lo = QSize((int)d->ra->orig.right, (int)d->ra->orig.bottom);
    else if (min.isArray()) lo = QSize(min.toArray()[0].toInt(), min.toArray()[1].toInt());
    if (max.isArray()) hi = QSize(max.toArray()[0].toInt(), max.toArray()[1].toInt());
    cl->setMinimumSize(lo);
    cl->setMaximumSize(hi);
}
QString raInit(Dlg *d, const QString &spec) {
    const QJsonObject o = QJsonDocument::fromJson(spec.toUtf8()).object();
    auto ra = std::make_shared<Ra>();
    const QJsonArray def = o["def"].toArray();
    for (int k = 0; k < 4; ++k) ra->def[k] = raEdge(def[k]);
    QWidget *cl = d->client;
    ra->orig = {0, 0, (double)cl->width(), (double)cl->height()};
    std::set<int> seen;
    auto add = [&](int id, const RaEdge *edges) {
        auto it = d->ctrls.find(id);
        if (it == d->ctrls.end() || seen.count(id) || it->second.el->parentWidget() != cl) return;
        seen.insert(id);
        RaItem item;
        item.id = id; item.el = it->second.el;
        for (int k = 0; k < 4; ++k) item.edges[k] = edges[k];
        item.orig = item.cur = raRect(item.el);
        ra->items.push_back(item);
    };
    for (const QJsonValue &row : o["ctrls"].toArray()) {
        const QJsonArray r = row.toArray();
        RaEdge e[4];
        for (int k = 0; k < 4; ++k) e[k] = raEdge(r[k + 1]);
        add(r[0].toInt(), e);
    }
    for (int id : d->order) if (!d->ctrls[id].parentCtl) add(id, ra->def);
    ra->ended = o["ended"].toInt() != 0;
    d->ra = ra;
    raLimits(d, o["min"], o["max"]);
    if (!d->sizeWatched) cl->installEventFilter(new SizeWatch(d, cl->size(), cl));   // a dialog with no sizing border becomes sizable
    return "1";
}
void raPages(Dlg *d);
void raLayout(Dlg *d) {
    Ra &ra = *d->ra;
    const RaBox now = {0, 0, (double)d->client->width(), (double)d->client->height()};
    auto rects = [&](int id) -> std::pair<RaBox, RaBox> {
        if (id) for (auto &it : ra.items) if (it.id == id) return {it.orig, it.cur};
        return {ra.orig, now};
    };
    auto coord = [](const QString &edge, const RaBox &r) {
        if (edge == "LEFT") return r.left;
        if (edge == "TOP") return r.top;
        if (edge == "RIGHT") return r.right;
        if (edge == "BOTTOM") return r.bottom;
        if (edge == "XCENTER") return (r.left + r.right) / 2;
        return (r.top + r.bottom) / 2;                    // YCENTER
    };
    auto side = [](const RaBox &r, int k) { return k == 0 ? r.left : k == 1 ? r.top : k == 2 ? r.right : r.bottom; };
    auto span = [](int k, const RaBox &r) { return k == 0 || k == 2 ? r.right - r.left : r.bottom - r.top; };
    for (auto &it : ra.items) {
        it.cur = RaBox();
        double v[4];
        for (int k = 0; k < 4; ++k) {
            const RaEdge &e = it.edges[k];
            const auto [pi, pc] = rects(e.to);
            double x;
            if (e.type == "S") x = side(it.orig, k) - coord(e.edge, pi) + coord(e.edge, pc);
            else if (e.type == "ML") x = it.cur.left + (it.orig.right - it.orig.left);
            else if (e.type == "MT") x = it.cur.top + (it.orig.bottom - it.orig.top);
            else {                                        // proportional: to the same edge of the window pinned to
                const double was = span(k, pi) ? span(k, pi) : 1;
                x = side(pc, k) + (side(it.orig, k) - side(pi, k)) * (span(k, pc) / was);
            }
            v[k] = std::trunc(x);
            if (k == 0) it.cur.left = v[0];
            if (k == 1) it.cur.top = v[1];
            if (k == 2) it.cur.right = v[2];
            if (k == 3) it.cur.bottom = v[3];
        }
        it.el->setGeometry((int)v[0], (int)v[1], std::max(0, (int)(v[2] - v[0])), std::max(0, (int)(v[3] - v[1])));
    }
    raPages(d);
}
/* pagedTab (v0.19.0): op(key, tabId, "ra.page", childKey) names an embedded dialog as a page of that tab
 * control.  After each layout every page takes the tab's display area, 2 pixels in (handleChildDialogs of
 * oodResizableDialog.cpp); a page with a ResizingAdmin definition of its own is laid out by its size change. */
void raPages(Dlg *d) {
    for (auto &kv : d->ctrls) {
        auto t = kv.second.tab;
        if (!t || t->raPages.empty()) continue;
        if (auto *tb = dynamic_cast<TabBox *>(t->box)) tb->lay();   // the strip and frame first, at the tab's new size
        const QRect g = t->box->geometry();
        const int strip = t->bar->sizeHint().height();
        const QRect area(g.left() + 2, g.top() + strip + 2, std::max(0, g.width() - 4), std::max(0, g.height() - strip - 4));
        for (int k : t->raPages) {
            if (!dialogs.count(k)) continue;
            Dlg *page = dialogs[k];
            page->client->setFixedSize(area.size());
            page->win->adjustSize();
            page->win->move(area.topLeft());
        }
    }
}

/* The client area of a control, as Windows has it: inside its frame (a list-view's includes its header). */
QPoint clientOrigin(QWidget *el) {
    int f = 0;
    if (auto *fr = qobject_cast<QFrame *>(el)) f = fr->frameWidth();
    return el->pos() + QPoint(f, f);
}

/* isGrandChild(): RETURN, ESCAPE and (when asked) TAB, and losing the focus, go to the dialog as GC events
 * rather than to the default button or Cancel; the program ends the in-place edit with them. */
class GrandChild : public QObject {
public:
    Dlg *d; int id; bool tab;
    GrandChild(Dlg *dd, int i, bool t, QObject *parent) : QObject(parent), d(dd), id(i), tab(t) {}
    bool eventFilter(QObject *o, QEvent *e) override {
        if (e->type() == QEvent::KeyPress || e->type() == QEvent::ShortcutOverride) {
            const int k = static_cast<QKeyEvent *>(e)->key();
            const QString key = k == Qt::Key_Return || k == Qt::Key_Enter ? "enter" : k == Qt::Key_Escape ? "escape" : k == Qt::Key_Tab ? "tab" : "";
            if (key.isEmpty()) return false;
            e->accept();
            if (e->type() == QEvent::KeyPress && (key != "tab" || tab)) fire(d->key, "GC", QString::number(id), key);
            return true;                                   // not the dialog's default button, not its Cancel
        }
        if (e->type() == QEvent::FocusOut) {
            auto *w = static_cast<QWidget *>(o);
            if (w->isVisible()) fire(d->key, "GC", QString::number(id), "killfocus");
        }
        return false;
    }
};

/* LB_SETTABSTOPS: a list box shows each tab filled out to the next stop; its items keep their own text. */
class TabStopDelegate : public QStyledItemDelegate {
public:
    QList<int> stops;
    using QStyledItemDelegate::QStyledItemDelegate;
    static int nextStop(const QList<int> &stops, int at) {
        for (int s : stops) if (s > at) return s;
        const int last = stops.isEmpty() ? 32 : stops.last();
        const int step = stops.size() > 1 ? last - stops[stops.size() - 2] : last;
        int s = last;
        while (s <= at) s += std::max(8, step);
        return s;
    }
    void paint(QPainter *p, const QStyleOptionViewItem &opt, const QModelIndex &ix) const override {
        const QString text = ix.data().toString();
        if (!text.contains('\t')) { QStyledItemDelegate::paint(p, opt, ix); return; }
        QStyleOptionViewItem o(opt);
        initStyleOption(&o, ix);
        o.text.clear();
        o.widget->style()->drawControl(QStyle::CE_ItemViewItem, &o, p, o.widget);   // background and selection
        const QFontMetrics fm(o.font);
        const int left = o.rect.left() + 3;
        int x = 0;
        p->save();
        p->setPen(o.palette.color(o.state & QStyle::State_Selected ? QPalette::HighlightedText : QPalette::Text));
        const QStringList parts = text.split('\t');
        for (int k = 0; k < parts.size(); ++k) {
            p->drawText(QPoint(left + x, o.rect.top() + (o.rect.height() + fm.ascent() - fm.descent()) / 2), parts[k]);
            x += fm.horizontalAdvance(parts[k]);
            if (k < parts.size() - 1) x = nextStop(stops, x);
        }
        p->restore();
    }
};

/*---- the mouse (oodWeb's Mouse class): as the page, Windows mouse messages for a dialog (id 0) or a control ----
 * An event goes to Rexx as MOUSE id NAME "state x y delta": state is getMouseArgs()'s words joined with commas
 * (None when nothing is down), x y are in the host's client area (the screen's for MOUSEWHEEL), delta the
 * wheel's +-120.  An event over a control reaches every connected host it is inside, as the page's do; while
 * a window has captured the mouse, moves and button releases anywhere are its own. */
struct MouseHost { Dlg *d; int id; };
std::map<QWidget *, MouseHost> mouseHosts;
struct { Dlg *d = nullptr; int id = 0; QWidget *host = nullptr; } mouseCapture;
QString cursorName;                                    // the page's body cursor: a CSS name or an image key
QWidget *mouseHostOf(Dlg *d, int id) {
    if (!id) return d->client;
    auto it = d->ctrls.find(id);
    return it == d->ctrls.end() ? nullptr : it->second.el;
}
QString mouseState(Qt::MouseButtons b, Qt::KeyboardModifiers m) {
    QStringList w;
    if (m & Qt::ControlModifier) w << "Control";
    if (b & Qt::LeftButton) w << "lButton";
    if (b & Qt::MiddleButton) w << "mButton";
    if (b & Qt::RightButton) w << "rButton";
    if (m & Qt::ShiftModifier) w << "Shift";
    return w.isEmpty() ? "None" : w.join(',');
}
class MouseHub : public QObject {
public:
    using QObject::QObject;
    std::map<QWidget *, qint64> lastMove;
    std::map<QWidget *, std::pair<QString, QPointF>> pendingMove;   // a move held back by the 30 ms rule
    std::map<QWidget *, QTimer *> moveTimer;
    std::map<QWidget *, QTimer *> hover;
    quint64 lastStamp = 0; int lastType = 0; QPointF lastGlobal;
    static QString button(Qt::MouseButton b) { return b == Qt::RightButton ? "R" : b == Qt::MiddleButton ? "M" : "L"; }
    bool deliver(QWidget *host, const QString &name, const QString &state, QPointF global, int delta) {
        auto h = mouseHosts.find(host);
        if (h == mouseHosts.end()) return false;
        MouseHost mh = h->second;
        if (!dialogs.count(mh.d->key) || !mh.d->mouseSubs.count(QString::number(mh.id) + "." + name)) return false;
        if (name == "MOUSEMOVE") {                         // at most one move in 30 ms, as the page; the last one is never lost
            const qint64 now = QDateTime::currentMSecsSinceEpoch();
            if (now - lastMove[host] < 30) {
                pendingMove[host] = {state, global};
                if (!moveTimer.count(host)) {
                    QTimer *tm = new QTimer(host); tm->setSingleShot(true);
                    QObject::connect(tm, &QTimer::timeout, [this, host] {
                        auto p = pendingMove.find(host);
                        if (p == pendingMove.end()) return;
                        const auto [st, g] = p->second;
                        pendingMove.erase(p);
                        lastMove[host] = 0;
                        deliver(host, "MOUSEMOVE", st, g, 0);
                    });
                    moveTimer[host] = tm;
                }
                if (!moveTimer[host]->isActive()) moveTimer[host]->start(int(30 - (now - lastMove[host])));
                return true;
            }
            lastMove[host] = now;
            pendingMove.erase(host);
        }
        const QPoint p = name == "MOUSEWHEEL" ? global.toPoint() : host->mapFromGlobal(global.toPoint());
        fire(mh.d->key, "MOUSE", QString::number(mh.id), name, state + " " + QString::number(p.x()) + " " + QString::number(p.y()) + " " + QString::number(delta));
        return true;
    }
    bool eventFilter(QObject *o, QEvent *e) override {
        const int t = e->type();
        auto *w = qobject_cast<QWidget *>(o);
        if (!w || mouseHosts.empty()) return false;
        if (t == QEvent::Leave || t == QEvent::Enter) {   // not propagated: only a host itself
            if (!mouseHosts.count(w)) return false;
            if (t == QEvent::Leave) {
                if (hover.count(w)) hover[w]->stop();
                deliver(w, "MOUSELEAVE", mouseState(QApplication::mouseButtons(), QApplication::keyboardModifiers()), QCursor::pos(), 0);
            } else {
                QTimer *&tm = hover[w];
                if (!tm) {
                    tm = new QTimer(w); tm->setSingleShot(true); tm->setInterval(400);
                    QObject::connect(tm, &QTimer::timeout, [this, w] { deliver(w, "MOUSEHOVER", mouseState(QApplication::mouseButtons(), QApplication::keyboardModifiers()), QCursor::pos(), 0); });
                }
                tm->start();
            }
            return false;
        }
        QString name; QPointF global; QString state; int delta = 0;
        quint64 stamp = 0;
        if (t == QEvent::MouseButtonPress || t == QEvent::MouseButtonRelease || t == QEvent::MouseButtonDblClick || t == QEvent::MouseMove) {
            auto *me = static_cast<QMouseEvent *>(e);
            global = me->globalPosition(); stamp = me->timestamp();
            state = mouseState(me->buttons(), me->modifiers());
            name = t == QEvent::MouseMove ? "MOUSEMOVE" : button(me->button()) + (t == QEvent::MouseButtonPress ? "BUTTONDOWN" : t == QEvent::MouseButtonRelease ? "BUTTONUP" : "BUTTONDBLCLK");
        } else if (t == QEvent::Wheel) {
            auto *we = static_cast<QWheelEvent *>(e);
            global = we->globalPosition(); stamp = we->timestamp();
            state = mouseState(we->buttons(), we->modifiers());
            name = "MOUSEWHEEL"; delta = we->angleDelta().y() > 0 ? 120 : -120;
        } else return false;
        // Qt passes an event a child ignores on to its parent: the same event, seen once
        if (stamp == lastStamp && t == lastType && global == lastGlobal) return false;
        lastStamp = stamp; lastType = t; lastGlobal = global;
        QWidget *under = w;
        if (t == QEvent::MouseMove || t == QEvent::MouseButtonRelease) {   // the page's pointer: the element under it, not Qt's grab
            if (QWidget *at = QApplication::widgetAt(global.toPoint())) under = at;
        }
        if (mouseCapture.host && name != "MOUSEWHEEL") {   // captured: the capturing window's alone
            if (!dialogs.count(mouseCapture.d->key)) { mouseCapture = {}; }
            else { deliver(mouseCapture.host, name, state, global, delta); return false; }
        }
        bool took = false;
        for (QWidget *x = under; x; x = x->isWindow() ? nullptr : x->parentWidget()) took = deliver(x, name, state, global, delta) || took;
        return name == "MOUSEWHEEL" && took;               // a connected MOUSEWHEEL takes the wheel, as the page's preventDefault
    }
};

QCursor cursorFor(const QString &n) {                  // a CSS cursor name, or the key of a .cur/.ico image Rexx sent
    auto it = images.find(n);
    if (it != images.end() && !it->second.second.isNull()) return QCursor(it->second.second);
    static const std::map<QString, Qt::CursorShape> css = {
        {"default", Qt::ArrowCursor}, {"auto", Qt::ArrowCursor}, {"", Qt::ArrowCursor}, {"not-allowed", Qt::ForbiddenCursor},
        {"no-drop", Qt::ForbiddenCursor}, {"crosshair", Qt::CrossCursor}, {"wait", Qt::WaitCursor}, {"progress", Qt::BusyCursor},
        {"pointer", Qt::PointingHandCursor}, {"text", Qt::IBeamCursor}, {"move", Qt::SizeAllCursor}, {"help", Qt::WhatsThisCursor},
        {"ns-resize", Qt::SizeVerCursor}, {"ew-resize", Qt::SizeHorCursor}, {"nesw-resize", Qt::SizeBDiagCursor},
        {"nwse-resize", Qt::SizeFDiagCursor}, {"col-resize", Qt::SplitHCursor}, {"row-resize", Qt::SplitVCursor},
        {"grab", Qt::OpenHandCursor}, {"grabbing", Qt::ClosedHandCursor}, {"none", Qt::BlankCursor}};
    auto s = css.find(n);
    return QCursor(s == css.end() ? Qt::ArrowCursor : s->second);
}

QString mouseOp(Dlg *d, int id, const QString &verb, const QString &a) {
    QWidget *host = mouseHostOf(d, id);
    auto who = [](Dlg *x, int i) { return x ? QString::number(x->key) + " " + QString::number(i) : QString(); };
    if (verb == "capture") { const QString old = who(mouseCapture.d, mouseCapture.id); mouseCapture = {d, id, host}; return old; }
    if (verb == "release") { const QString old = who(mouseCapture.d, mouseCapture.id); mouseCapture = {}; return old; }
    if (verb == "getCapture") return who(mouseCapture.d, mouseCapture.id);
    if (verb == "state") {                                  // where the pointer is and which buttons are down (1 left, 2 right, 4 middle)
        const QPoint p = QCursor::pos();
        const Qt::MouseButtons b = QApplication::mouseButtons() | playerButtons;
        const int bits = (b & Qt::LeftButton ? 1 : 0) | (b & Qt::RightButton ? 2 : 0) | (b & Qt::MiddleButton ? 4 : 0);
        return QString::number(p.x()) + " " + QString::number(p.y()) + " " + QString::number(bits);
    }
    if (verb == "cursor") {
        const QString old = cursorName;
        cursorName = a;
        const QCursor cur = cursorFor(a);
        for (auto &kv : dialogs) kv.second->win->setCursor(cur);
        return old;
    }
    return "";
}

/*---- GDI: a device context is a transparent layer over the client area or one control ----
 * As oodialog-web.js's canvas: Rexx (oodWeb.cls) keeps the DC's state, every call brings what it needs.
 * values: the call's numbers and text; style: stroke, width, dash, fill, font, textColour, bkMode (O|T),
 * bkColour, align words.  The layer takes no mouse events, so the control under it still works. */
class GdiLayer : public QWidget {
public:
    QImage img;
    using QWidget::QWidget;
    void fit(const QSize &s) {
        if (img.size() == s) return;
        QImage n(s.expandedTo(QSize(1, 1)), QImage::Format_ARGB32_Premultiplied);
        n.fill(Qt::transparent);
        if (!img.isNull()) { QPainter p(&n); p.drawImage(0, 0, img); }
        img = n;
    }
protected:
    void paintEvent(QPaintEvent *) override { QPainter p(this); p.drawImage(0, 0, img); }
};

GdiLayer *gdiLayer(Dlg *d, Ctl *c) {
    const int id = c ? c->id : 0;
    GdiLayer *g = static_cast<GdiLayer *>(d->gdi.count(id) ? d->gdi[id] : nullptr);
    if (!g) {
        g = new GdiLayer(d->client);
        g->setObjectName("ood-gdi");
        g->setAttribute(Qt::WA_TransparentForMouseEvents);
        g->setAttribute(Qt::WA_NoSystemBackground);
        d->gdi[id] = g;
        g->show();
    }
    const QRect r = c ? QRect(c->el->mapTo(d->client, QPoint(0, 0)), c->el->size()) : d->client->rect();
    g->setGeometry(r);
    g->fit(r.size());
    g->raise();
    return g;
}

QFont gdiFont(const QString &css, const QFont &dflt) {     // [italic] [bold] Npt "Name", sans-serif
    if (css.isEmpty()) return dflt;
    static const QRegularExpression re(R"re(^((?:italic|bold|\s)*)\s*([\d.]+)pt\s+"([^"]*)")re");
    const auto m = re.match(css);
    if (!m.hasMatch()) return dflt;
    QFont f(m.captured(3));
    f.setPixelSize(std::max(1, qRound(m.captured(2).toDouble() * 96 / 72)));
    f.setItalic(m.captured(1).contains("italic"));
    f.setBold(m.captured(1).contains("bold"));
    return f;
}

QString gdi(Dlg *d, Ctl *c, const QString &verb, const QStringList &v, const QStringList &st) {
    if (verb == "ownerDraw") {                            // the program draws it: no text of its own
        if (c) { QPalette p = c->main->palette(); for (auto r : {QPalette::ButtonText, QPalette::WindowText, QPalette::Text}) p.setColor(r, Qt::transparent); c->main->setPalette(p); }
        return "1";
    }
    GdiLayer *layer = gdiLayer(d, c);
    QImage &img = layer->img;
    auto n = [&](int i) { return v.value(i).toDouble(); };
    const QString stroke = st.value(0), dash = st.value(2), fill = st.value(3), font = st.value(4),
                  textColor = st.value(5), bkMode = st.value(6), bkColor = st.value(7), align = st.value(8);
    const int lw = std::max(1, st.value(1).toInt());
    auto pen = [&]() {
        QPen p(QColor(stroke.isEmpty() ? "#000000" : stroke), lw, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
        if (dash == "DASH") p.setStyle(Qt::DashLine); else if (dash == "DOT") p.setStyle(Qt::DotLine);
        else if (dash == "DASHDOT") p.setStyle(Qt::DashDotLine); else if (dash == "DASHDOTDOT") p.setStyle(Qt::DashDotDotLine);
        else if (dash == "NULL") p.setStyle(Qt::NoPen);
        return p;
    };
    auto brush = [&]() -> QBrush {
        if (fill.isEmpty()) return Qt::NoBrush;
        if (fill.startsWith("hatch:")) {
            const QString kind = fill.section(':', 1, 1);
            const Qt::BrushStyle s = kind == "HORIZONTAL" ? Qt::HorPattern : kind == "VERTICAL" ? Qt::VerPattern : kind == "CROSS" ? Qt::CrossPattern
                                   : kind == "UPDIAGONAL" ? Qt::BDiagPattern : kind == "DOWNDIAGONAL" ? Qt::FDiagPattern : Qt::DiagCrossPattern;
            return QBrush(QColor(fill.section(':', 2)), s);
        }
        return QBrush(QColor(fill));
    };
    auto done = [&](const QString &r) { layer->update(); return r; };
    const QRectF box(std::min(n(0), n(2)), std::min(n(1), n(3)), std::abs(n(2) - n(0)), std::abs(n(3) - n(1)));
    if (verb == "size") return QString::number(img.width()) + " " + QString::number(img.height());
    if (verb == "getPixel") {
        const int x = n(0), y = n(1);
        if (x < 0 || y < 0 || x >= img.width() || y >= img.height()) return "-1";
        const QColor px = img.pixelColor(x, y);
        return px.alpha() == 0 ? "-1" : QString::number(px.red() + px.green() * 256 + px.blue() * 65536);
    }
    if (verb == "flood") {                                // FloodFill(): from x, y out to the border colour
        const int x0 = qRound(n(0)), y0 = qRound(n(1)), W = img.width(), H = img.height();
        if (x0 < 0 || y0 < 0 || x0 >= W || y0 >= H || fill.isEmpty()) return "0";
        const QColor bc(v.value(2)), fc(fill.startsWith("hatch:") ? fill.section(':', 2) : fill);
        auto near = [&](QRgb p, const QColor &k) { return qAlpha(p) > 40 && std::abs(qRed(p) - k.red()) + std::abs(qGreen(p) - k.green()) + std::abs(qBlue(p) - k.blue()) < 150; };
        std::vector<uint8_t> seen(W * H, 0);
        std::vector<int> stack{x0 + y0 * W};
        img = img.convertToFormat(QImage::Format_ARGB32);
        while (!stack.empty()) {
            const int p = stack.back(); stack.pop_back();
            if (seen[p]) continue;
            seen[p] = 1;
            const int x = p % W, y = p / W;
            if (near(img.pixel(x, y), bc)) continue;     // the border stops the fill
            img.setPixel(x, y, fc.rgb());
            if (x > 0) stack.push_back(p - 1);
            if (x < W - 1) stack.push_back(p + 1);
            if (y > 0) stack.push_back(p - W);
            if (y < H - 1) stack.push_back(p + W);
        }
        img = img.convertToFormat(QImage::Format_ARGB32_Premultiplied);
        return done("1");
    }
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing, false);
    const double o = (lw % 2) ? 0.5 : 0;                  // odd widths on the pixel grid
    if (verb == "line") {
        if (dash == "NULL") return "1";
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setPen(pen()); p.drawLine(QPointF(n(0) + o, n(1) + o), QPointF(n(2) + o, n(3) + o));
        return done("1");
    }
    if (verb == "rect") {
        if (v.value(4) == "1" && !fill.isEmpty()) p.fillRect(box, brush());
        if (dash != "NULL") { p.setPen(pen()); p.setBrush(Qt::NoBrush); p.drawRect(box.translated(o, o)); }
        return done("1");
    }
    if (verb == "arc") {                                  // Arc() and Pie(): counter-clockwise from the start radial to the end radial
        const double cx = box.center().x(), cy = box.center().y(), rx = box.width() / 2, ry = box.height() / 2;
        if (rx <= 0 || ry <= 0) return "0";
        const bool whole = n(4) == n(6) && n(5) == n(7), pie = v.value(8) == "1";
        auto ang = [&](double x, double y) { return std::atan2((y - cy) / ry, (x - cx) / rx) * 180 / M_PI; };   // clockwise on screen
        double start = whole ? 0 : -ang(n(4), n(5)), end = whole ? 360 : -ang(n(6), n(7));                      // Qt: counter-clockwise
        double span = end - start;
        const bool ccw = whole || v.value(9) != "CLOCKWISE";
        if (!whole) { if (ccw) { while (span <= 0) span += 360; } else { while (span >= 0) span -= 360; } }
        p.setRenderHint(QPainter::Antialiasing, true);
        QPainterPath path;
        if (whole) path.addEllipse(box);
        else if (pie) { path.moveTo(cx, cy); path.arcTo(box, start, span); path.closeSubpath(); }
        else { path.arcMoveTo(box, start); path.arcTo(box, start, span); }
        if (pie && !fill.isEmpty()) p.fillPath(path, brush());
        if (dash != "NULL") p.strokePath(path, pen());
        return done("1");
    }
    if (verb == "angleArc") {                             // x, y, radius, start and sweep in degrees, counter-clockwise; fromX fromY
        const double r = std::max(0.0, n(2));
        const QRectF b(n(0) - r, n(1) - r, 2 * r, 2 * r);
        QPainterPath path;
        if (!v.value(5).isEmpty()) { path.moveTo(n(5), n(6)); QPainterPath t; t.arcMoveTo(b, n(3)); path.lineTo(t.currentPosition()); }
        else path.arcMoveTo(b, n(3));
        path.arcTo(b, n(3), n(4));
        p.setRenderHint(QPainter::Antialiasing, true);
        p.strokePath(path, pen());
        const double a2 = -(n(3) + n(4)) * M_PI / 180;
        layer->update();
        return QString::number(qRound(n(0) + r * std::cos(a2))) + " " + QString::number(qRound(n(1) + r * std::sin(a2)));
    }
    if (verb == "image") {                                // BitBlt(): key, x, y, xSource, ySource, width, height (0: all of it)
        auto it = images.find(v.value(0));
        if (it == images.end()) return "0";
        const QPixmap &src = it->second.second;
        const int w = n(5) ? (int)n(5) : src.width(), h = n(6) ? (int)n(6) : src.height();
        const int sw = std::min(w, src.width() - (int)n(3)), sh = std::min(h, src.height() - (int)n(4));
        if (sw > 0 && sh > 0) p.drawPixmap(QPointF(n(1), n(2)), src, QRectF(n(3), n(4), sw, sh));
        return done("1");
    }
    if (verb == "scroll") {                               // ScrollWindow(): what is drawn moves by dx, dy; then the part that moves
        const int dx = qRound(n(0)), dy = qRound(n(1));
        const bool all = v.value(2).isEmpty();
        const int l = all ? 0 : std::max(0, (int)n(2)), t = all ? 0 : std::max(0, (int)n(3));
        const int r = all ? img.width() : std::min(img.width(), (int)n(4)), b = all ? img.height() : std::min(img.height(), (int)n(5));
        const QRect part(l, t, r - l, b - t);
        if (part.width() <= 0 || part.height() <= 0) return "1";
        const QImage moving = img.copy(part);
        p.setCompositionMode(QPainter::CompositionMode_Source);
        p.fillRect(part, Qt::transparent);
        p.setClipRect(part);                              // what leaves the part is cut off
        p.drawImage(l + dx, t + dy, moving);
        return done("1");
    }
    if (verb == "pixel") { img.setPixelColor(qRound(n(0)), qRound(n(1)), QColor(v.value(2))); return done("1"); }
    if (verb == "fillRect") { if (!fill.isEmpty()) p.fillRect(box, brush()); return done("1"); }
    if (verb == "clear") {
        p.setCompositionMode(QPainter::CompositionMode_Clear);
        if (v.value(0).isEmpty()) p.fillRect(img.rect(), Qt::transparent); else p.fillRect(box, Qt::transparent);
        return done("1");
    }
    const QFont f = gdiFont(font, d->win->font());
    const QFontMetrics fm(f);
    if (verb == "extent") return QString::number(fm.horizontalAdvance(v.value(0))) + " " + QString::number(fm.ascent() + fm.descent());
    if (verb == "text") {
        p.setFont(f);
        p.setRenderHint(QPainter::TextAntialiasing, true);
        const QString words = " " + align + " ";
        const int lh = fm.ascent() + fm.descent();
        const QStringList lines = v.value(2).split('\n');
        for (int i = 0; i < lines.size(); ++i) {
            const QString t = lines[i];
            const int w = fm.horizontalAdvance(t);
            const double x0 = words.contains(" CENTER ") ? n(0) - w / 2.0 : words.contains(" RIGHT ") ? n(0) - w : n(0);
            const double y = n(1) + i * lh;
            const double top = words.contains(" BASELINE ") ? y - fm.ascent() : words.contains(" BOTTOM ") ? y - lh : y;
            if (bkMode == "O") p.fillRect(QRectF(x0, top, w, lh), QColor(bkColor.isEmpty() ? "#ffffff" : bkColor));
            p.setPen(QColor(textColor.isEmpty() ? "#000000" : textColor));
            p.drawText(QPointF(x0, top + fm.ascent()), t);
        }
        return done("1");
    }
    return "";
}

/*---- the renderer messages ----*/
QString call(const QString &name, const QString &payload) {
    QStringList a = payload.split(FS);
    for (QString &x : a) x.replace(QChar(0x1D), FS);     // js.cls sends an argument's own separators as 1D
    auto arg = [&](int i) { return i < a.size() ? a[i] : QString(); };

    if (name == "create") {                              // payload: spec record 1E control records ...
        const QStringList recs = payload.split(RS);
        auto spec = fields(recs.value(0));
        auto *d = new Dlg;
        d->key = spec["key"].toInt();
        d->opts = spec["opts"].toUpper();
        QWidget *host = nullptr;
        if (!spec["parent"].isEmpty()) if (Dlg *h = dialog(spec["parent"])) host = h->client;
        d->win = new OodDialog(d, nullptr);
        d->win->setObjectName("ood-dlg");
        d->win->setWindowTitle(spec["title"]);
        if (has(d->opts, "NOMENU")) d->win->setWindowFlag(Qt::WindowCloseButtonHint, false);
        auto *layout = new QVBoxLayout(d->win);
        layout->setContentsMargins(0, 0, 0, 0);
        layout->setSpacing(0);
        d->client = new QWidget(d->win);
        layout->addWidget(d->client);
        const QFont f = dialogFont(spec["fontName"], spec["fontSize"].isEmpty() ? 8 : spec["fontSize"].toDouble());
        d->win->setFont(f);
        baseUnits(f, d->fx, d->fy);
        const int w = (int)std::lround(spec["cx"].toDouble() * d->fx), h = (int)std::lround(spec["cy"].toDouble() * d->fy);
        if (!spec["parent"].isEmpty() || !has(d->opts, "THICKFRAME")) d->client->setFixedSize(w, h);
        else {                                            // a sizing border: the window opens at the design size and can be dragged
            d->client->setMinimumSize(w, h);
            d->win->adjustSize();
            d->client->setMinimumSize(60, 30);
            d->client->installEventFilter(new SizeWatch(d, QSize(w, h), d->client));
        }
        if (host) d->win->setObjectName("ood-child");          // a ControlDialog or a property sheet page, drawn inside its owner
        if (host) { d->win->setParent(host); d->win->setWindowFlags(Qt::Widget); d->win->move(spec["px"].toInt(), spec["py"].toInt()); }
        else if (has(d->opts, "CENTER")) {
            const QRect s = QGuiApplication::primaryScreen()->availableGeometry();
            d->win->move(s.center() - QPoint(w / 2, h / 2));
        } else d->win->move((int)std::lround(spec["x"].toDouble() * d->fx), (int)std::lround(spec["y"].toDouble() * d->fy));
        dialogs[d->key] = d;
        for (int i = 1; i < recs.size(); ++i) addControl(d, fields(recs[i]));
        return QString::number(d->fx) + " " + QString::number(d->fy) + " " + QString::number(w) + " " + QString::number(h);
    }
    if (name == "addControl") {
        Dlg *d = dialog(arg(0)); if (!d) return "0";
        addControl(d, fields(payload.section(RS, 1)));
        return "1";
    }
    if (name == "show") {
        Dlg *d = dialog(arg(0)); if (!d) return "0";
        if (has(arg(1), "HIDE")) { d->win->hide(); return "1"; }
        d->win->show();
        d->win->raise();
        d->win->activateWindow();
        if (!d->shown) {
            d->shown = true;
            for (int id : d->order) {
                QWidget *m = d->ctrls[id].main;
                if (m->focusPolicy() & Qt::TabFocus && m->isEnabled() && m->isVisible()) { m->setFocus(); break; }
            }
        }
        return "1";
    }
    if (name == "destroy") {
        Dlg *d = dialog(arg(0)); if (!d) return "0";
        if (tipBox.d == d) { tipHide(true); tipBox.d = nullptr; }          // the tip box and the watchers hold no dialog that is gone
        if (treeTip.d == d) { if (treeTip.timer) treeTip.timer->stop(); treeTip.d = nullptr; treeTip.id = treeTip.h = 0; }
        if (tipWatch && tipWatch->last == d) tipWatch->last = nullptr;
        dialogs.erase(d->key);
        d->win->hide();
        d->win->deleteLater();
        delete d;
        return "1";
    }
    if (name == "sub") {
        Dlg *d = dialog(arg(0)); if (d) d->subs.insert(arg(1) + "." + arg(2));
        return "1";
    }
    if (name == "screen") {
        const QRect s = QGuiApplication::primaryScreen()->geometry();
        return QString::number(s.width()) + " " + QString::number(s.height());
    }
    if (name == "measure") {
        const QFont f = dialogFont(arg(1), arg(2).isEmpty() ? 8 : arg(2).toDouble());
        double fx, fy;
        baseUnits(f, fx, fy);
        const QRect r = QFontMetrics(f).boundingRect(QRect(0, 0, 100000, 100000), Qt::AlignLeft | Qt::AlignTop, arg(0));
        return QString::number((int)std::ceil(r.width() / fx)) + " " + QString::number((int)std::ceil(r.height() / fy)) + " "
               + QString::number(r.width()) + " " + QString::number(r.height()) + " " + QString::number(fx) + " " + QString::number(fy);
    }
    if (name == "setMenu") {
        Dlg *d = dialog(arg(0)); if (!d) return "0";
        if (d->menuBar) { delete d->menuBar; d->menuBar = nullptr; }
        const QString data = arg(1);
        if (data.isEmpty()) return "1";
        d->menuBar = new QMenuBar(d->win);
        d->menuBar->setObjectName("ood-menubar");
        buildMenu(d, d->menuBar, data);
        static_cast<QVBoxLayout *>(d->win->layout())->setMenuBar(d->menuBar);
        return "1";
    }
    if (name == "msgBox") {                              // token, text, title, buttons, icon
        const QString token = arg(0), buttons = arg(3).toUpper(), icon = arg(4).toUpper();
        auto *m = new QMessageBox;
        m->setObjectName("ood-msgbox");
        m->setText(arg(1));
        m->setWindowTitle(arg(2));
        struct B { const char *word; QMessageBox::StandardButton b; int id; };
        static const B all[] = {{"ABORT", QMessageBox::Abort, 3}, {"RETRY", QMessageBox::Retry, 4}, {"IGNORE", QMessageBox::Ignore, 5},
                         {"YES", QMessageBox::Yes, 6}, {"NO", QMessageBox::No, 7}, {"OK", QMessageBox::Ok, 1}, {"CANCEL", QMessageBox::Cancel, 2}};
        QMessageBox::StandardButtons set;
        for (const B &b : all) if (buttons.contains(b.word)) set |= b.b;
        if (!set) set = QMessageBox::Ok;
        m->setStandardButtons(set);
        if (icon.contains("ERROR") || icon.contains("STOP") || icon.contains("HAND")) m->setIcon(QMessageBox::Critical);
        else if (icon.contains("QUESTION")) m->setIcon(QMessageBox::Question);
        else if (icon.contains("WARN") || icon.contains("EXCLAMATION")) m->setIcon(QMessageBox::Warning);
        else if (icon.contains("INFO") || icon.contains("ASTERISK")) m->setIcon(QMessageBox::Information);
        QObject::connect(m, &QMessageBox::finished, [m, token](int) {
            int id = 2;
            const auto clicked = m->standardButton(m->clickedButton());
            for (const B &b : all) if (b.b == clicked) id = b.id;
            fire(0, "MSGBOX", token, QString::number(id));
            m->deleteLater();
        });
        m->show();
        return "1";
    }
    if (name == "image") {                               // name, data URL: Rexx sends each file once
        const QString url = arg(1);
        QPixmap px;
        px.loadFromData(QByteArray::fromBase64(url.section(',', 1).toLatin1()));
        images[arg(0)] = {url.section(',', 0, 0), px};
        return "1";
    }
    if (name == "hasImage") return images.count(arg(0)) ? "1" : "0";
    if (name == "popupMenu") {                           // token, x, y, data
        const QString token = arg(0);
        auto *menu = new QMenu;                          // the choice comes back as MSGBOX(token, id); 0 = none
        menu->setObjectName("ood-menu");
        auto chosen = std::make_shared<int>(0);
        for (const QString &r0 : arg(3).split(RS, Qt::SkipEmptyParts)) {
            const QStringList r = r0.split(FS);
            if (r.size() < 3 || r[0].toInt() != 0) continue;
            if ((" " + r.value(3) + " ").contains(" SEPARATOR ")) { menu->addSeparator(); continue; }
            QAction *act = menu->addAction(r[2]);
            const int id = r[1].toInt();
            QObject::connect(act, &QAction::triggered, [chosen, id] { *chosen = id; });
        }
        QObject::connect(menu, &QMenu::aboutToHide, [menu, token, chosen] {
            QTimer::singleShot(0, [menu, token, chosen] { fire(0, "MSGBOX", token, QString::number(*chosen)); menu->deleteLater(); });
        });
        menu->popup(QPoint(arg(1).toInt(), arg(2).toInt()));
        return "1";
    }
    if (name == "msg") {                                  // key, id, msg, wParam, lParam
        Dlg *d = dialog(arg(0)); if (!d) return "0";
        auto it = d->ctrls.find(arg(1).toInt()); if (it == d->ctrls.end()) return "0";
        Ctl &c = it->second;
        const int msg = arg(2).toInt(), w = arg(3).toInt(), l = arg(4).toInt();
        if (c.mc) {
            switch (msg) {
            case 0x1015: return mcOp(d, c.id, *c.mc, "todayWidth", "", "");                       // MCM_GETMAXTODAYWIDTH
            case 0x1003: case 0x1013: return "1";                                                  // MCM_GETMAXSELCOUNT, MCM_GETMONTHDELTA
            }
            return "0";
        }
        if (auto *b = qobject_cast<QAbstractButton *>(c.main)) {
            auto *cb = qobject_cast<QCheckBox *>(b);
            switch (msg) {
            case 0xF5: b->click(); return "0";
            case 0xF0: if (cb && cb->isTristate()) return QString::number(cb->checkState() == Qt::PartiallyChecked ? 2 : cb->isChecked() ? 1 : 0);
                       return b->isChecked() ? "1" : "0";
            case 0xF1: if (cb && cb->isTristate()) cb->setCheckState(w == 2 ? Qt::PartiallyChecked : w == 1 ? Qt::Checked : Qt::Unchecked);
                       else b->setChecked(w == 1);
                       return "0";
            case 0xF2: return QString::number((b->isChecked() ? 1 : 0) | (b->isDown() ? 4 : 0) | (b->hasFocus() ? 8 : 0));   // BM_GETSTATE
            case 0xF3: b->setDown(w != 0); return "0";                                                        // BM_SETSTATE: drawn pushed or not
            }
        }
        if (c.lv) {
            Lv &L = *c.lv;
            switch (msg) {
            case 0x1004: return QString::number(L.rows.size());                                          // LVM_GETITEMCOUNT
            case 0x1032: { int n = 0; for (auto &r : L.rows) n += r.sel ? 1 : 0; return QString::number(n); } // LVM_GETSELECTEDCOUNT
            case 0x101D: return QString::number(w >= 0 && w < (int)L.cols.size() ? std::max(0, qRound(L.cols[w].w)) : 0); // LVM_GETCOLUMNWIDTH
            case 0x1013: if (w >= 0 && w < L.w->topLevelItemCount()) L.w->scrollToItem(L.w->topLevelItem(w)); return "1";
            case 0x102F: case 0x1027: case 0x102A: case 0x1015: return "0";
            }
        }
        if (c.tv) {
            switch (msg) {
            case 0x1105: return QString::number(c.tv->nodes.size());                                     // TVM_GETCOUNT
            case 0x1114: return "1";                                                                     // TVM_ENSUREVISIBLE
            }
        }
        if (c.tab) {
            TabC &t = *c.tab;
            const int n = t.tabs.size();
            switch (msg) {
            case 0x1304: return QString::number(n);                                                      // TCM_GETITEMCOUNT
            case 0x130B: case 0x132F: return QString::number(t.cur);                                     // TCM_GETCURSEL, TCM_GETCURFOCUS
            case 0x130C: { const int old = t.cur; if (w >= 0 && w < n) { t.cur = w; tabRender(t); } return QString::number(old); } // TCM_SETCURSEL
            case 0x1330: if (w >= 0 && w < n) { t.cur = w; tabRender(t); } return "0";                  // TCM_SETCURFOCUS
            case 0x1308: if (w < 0 || w >= n) return "0"; t.tabs.removeAt(w); if (t.cur >= t.tabs.size()) t.cur = t.tabs.size() - 1; tabRender(t); return "1";
            case 0x1309: t.tabs.clear(); t.cur = -1; tabRender(t); return "1";                          // TCM_DELETEALLITEMS
            case 0x132C: return "1";                                                                     // TCM_GETROWCOUNT
            case 0x1331: { const int was = t.minTab; t.minTab = l < 0 ? -1 : l; tabRender(t); return QString::number(was); }   // TCM_SETMINTABWIDTH: the width before
            }
        }
        if (auto *s = qobject_cast<QSlider *>(c.main)) {
            QSignalBlocker hush(s);
            switch (msg) {
            case 0x400: return QString::number(s->value());                              // TBM_GETPOS
            case 0x401: return QString::number(s->minimum());                            // TBM_GETRANGEMIN
            case 0x402: return QString::number(s->maximum());                            // TBM_GETRANGEMAX
            case 0x405: s->setValue(l); return "0";                                      // TBM_SETPOS
            case 0x406: s->setRange(l & 0xFFFF, (unsigned)l >> 16); return "0";          // TBM_SETRANGE
            case 0x407: s->setMinimum(l); return "0";                                    // TBM_SETRANGEMIN
            case 0x408: s->setMaximum(l); return "0";                                    // TBM_SETRANGEMAX
            case 0x415: { const int old = s->pageStep(); s->setPageStep(l); return QString::number(old); }   // TBM_SETPAGESIZE
            case 0x416: return QString::number(s->pageStep());
            case 0x417: { const int old = s->singleStep(); s->setSingleStep(l); return QString::number(old); } // TBM_SETLINESIZE
            case 0x418: return QString::number(s->singleStep());
            case 0x414: s->setTickInterval(w); return "0";                               // TBM_SETTICFREQ
            case 0x404: case 0x409: case 0x40A: case 0x40B: case 0x40C: case 0x413: return "0";
            case 0x410: return "2";
            }
        }
        if (c.kind == "UPDOWN") {
            switch (msg) {
            case 0x471: { const int old = c.pos; udSet(d, c, l); return QString::number(old); }                 // UDM_SETPOS32
            case 0x472: return QString::number(c.pos);                                                      // UDM_GETPOS32
            case 0x46F: c.lo = std::min(w, l); c.hi = std::max(w, l); udSet(d, c, c.pos); return "0";        // UDM_SETRANGE32
            case 0x46E: case 0x46D: return "10";                                                            // UDM_GETBASE, UDM_SETBASE
            }
        }
        if (auto *e = qobject_cast<QLineEdit *>(c.main)) {
            switch (msg) {
            case 0xB1: e->setSelection(w, (l < 0 ? e->text().size() : l) - w); return "1";
            case 0xB8: return c.modified ? "1" : "0";
            case 0xB9: c.modified = w != 0; return "0";
            case 0xBA: return "1";
            case 0xC5: e->setMaxLength(w > 0 ? w : 32767); return "0";
            case 0xCC: e->setEchoMode(w == 0 ? QLineEdit::Normal : QLineEdit::Password); return "0";
            case 0xD2: return e->echoMode() == QLineEdit::Password ? "42" : "0";
            case 0xCF: e->setReadOnly(w != 0); return "1";
            case 0x303: e->del(); return "0";
            }
        }
        if (auto *t = qobject_cast<QPlainTextEdit *>(c.main)) {
            switch (msg) {
            case 0xB8: return c.modified ? "1" : "0";
            case 0xB9: c.modified = w != 0; return "0";
            case 0xBA: return QString::number(t->blockCount());
            case 0xB5: {                                   // EM_SCROLL: line up, line down, page up, page down; lines moved in the low word
                QScrollBar *sb = t->verticalScrollBar();
                const int before = sb->value();
                static const QAbstractSlider::SliderAction act[] = {QAbstractSlider::SliderSingleStepSub, QAbstractSlider::SliderSingleStepAdd, QAbstractSlider::SliderPageStepSub, QAbstractSlider::SliderPageStepAdd};
                if (w >= 0 && w < 4) sb->triggerAction(act[w]);
                return QString::number(65536 + sb->value() - before);
            }
            case 0xCF: t->setReadOnly(w != 0); return "1";
            }
        }
        if (auto *lw = qobject_cast<QListWidget *>(c.main)) {
            switch (msg) {
            case 0x182: if (w < 0 || w >= lw->count()) return "-1"; delete lw->takeItem(w); return QString::number(lw->count());
            case 0x184: lw->clear(); return "0";
            case 0x185: if (l < 0) { for (int i = 0; i < lw->count(); ++i) lw->item(i)->setSelected(w != 0); }
                        else if (lw->item(l)) lw->item(l)->setSelected(w != 0);
                        return "0";
            case 0x186: lw->setCurrentRow(w); return QString::number(lw->currentRow());
            case 0x187: return lw->item(w) && lw->item(w)->isSelected() ? "1" : "0";
            case 0x188: return QString::number(lw->currentRow());
            case 0x18B: return QString::number(lw->count());
            case 0x190: return QString::number(lw->selectedItems().size());
            case 0x18E: return "0";
            }
        }
        if (auto *cb = qobject_cast<QComboBox *>(c.main)) {
            switch (msg) {
            case 0x144: if (w < 0 || w >= cb->count()) return "-1"; cb->removeItem(w); return QString::number(cb->count());
            case 0x146: return QString::number(cb->count());
            case 0x147: return QString::number(cb->currentIndex());
            case 0x14B: cb->clear(); if (cb->isEditable()) cb->setEditText(""); return "0";
            case 0x14E: cb->setCurrentIndex(w); return QString::number(cb->currentIndex());
            case 0x14F: if (w) cb->showPopup(); return "1";
            case 0x157: return "0";
            }
        }
        if (auto *p = qobject_cast<QProgressBar *>(c.main)) {
            switch (msg) {
            case 0x402: { const int old = p->value(); p->setValue(w); return QString::number(old); }   // PBM_SETPOS
            case 0x408: return QString::number(p->value());                                         // PBM_GETPOS
            }
        }
        return "0";
    }
    if (name == "op") {                                   // key, id, name, a, b, c
        Dlg *d = dialog(arg(0)); if (!d) return "";
        const int id = arg(1).toInt();
        const QString op = arg(2), oa = arg(3), ob = arg(4);
        if (op.startsWith("tip.")) return tipOp(d, id, op.mid(4), oa, ob);   // (a tool tip's ID is not a control's)
        Ctl *c = nullptr;
        if (id != 0) {
            auto it = d->ctrls.find(id);
            if (it == d->ctrls.end()) return op == "exists" ? "0" : "";
            c = &it->second;
        }
        QWidget *el = c ? c->el : (QWidget *)d->win, *m = c ? c->main : (QWidget *)d->win;
        const QString oc = arg(5);
        if (c && c->lv && op.startsWith("lv.")) return lvOp(d, id, c->lv, op.mid(3), oa, ob, oc);
        if (c && c->tv && op.startsWith("tv.")) return tvOp(d, id, c->tv, op.mid(3), oa, ob, oc);
        if (c && c->tab && op.startsWith("tab.")) return tabOp(d, c->tab, op.mid(4), oa, ob);
        if (c && c->mc && op.startsWith("mc.")) return mcOp(d, id, *c->mc, op.mid(3), oa, ob);
        if (c && op == "isDropList") { auto *cb = qobject_cast<QComboBox *>(m); return cb && !cb->isEditable() ? "1" : "0"; }
        if (op == "ra.init") return raInit(d, oa);
        if (op == "ra.page") { if (!c || !c->tab) return "0"; c->tab->raPages.push_back(oa.toInt()); return "1"; }   // pagedTab
        if (op == "ra.limits") { if (!d->ra) return "0"; raLimits(d, QJsonDocument::fromJson(("[" + oa + "]").toUtf8()).array()[0], QJsonDocument::fromJson(("[" + ob + "]").toUtf8()).array()[0]); return "1"; }
        if (c && op == "dtp.get") return dtpGet(*c);
        if (c && op == "dtp.set") { dtpSet(*c, QDateTime::fromString(oa, "yyyy-MM-ddTHH:mm:ss")); return "1"; }
        if (c && op == "ud.range") return QString::number(c->lo) + " " + QString::number(c->hi);
        if (c && op == "ud.buddy") { const int old = c->buddy; if (!oa.isEmpty()) c->buddy = oa.toInt(); return QString::number(old); }
        if (op == "pointFont") {                          // name, points, style letters B I U
            QFont f(oa);
            f.setPixelSize(std::max(1, qRound(ob.toDouble() * 96 / 72)));
            f.setBold(oc.contains('B')); f.setItalic(oc.contains('I')); f.setUnderline(oc.contains('U'));
            m->setFont(f);
            return "1";
        }
        if (op == "color") {                              // background, foreground as #rrggbb; empty leaves one as it is
            QPalette p = m->palette();
            if (!oa.isEmpty()) { p.setColor(QPalette::Window, QColor(oa)); p.setColor(QPalette::Base, QColor(oa)); p.setColor(QPalette::Button, QColor(oa)); m->setAutoFillBackground(true); }
            if (!ob.isEmpty()) { p.setColor(QPalette::WindowText, QColor(ob)); p.setColor(QPalette::Text, QColor(ob)); p.setColor(QPalette::ButtonText, QColor(ob)); }
            m->setPalette(p);
            return "1";
        }
        if (c && op == "image") {                         // a static's image; STRETCH fills the control
            auto *l = qobject_cast<QLabel *>(m);
            auto it = images.find(oa);
            if (l) { l->setScaledContents(ob == "STRETCH"); l->setPixmap(it == images.end() ? QPixmap() : it->second.second); }
            c->bmp = it == images.end() ? QString() : oa;
            return it == images.end() ? "0" : "1";
        }
        if (c && op == "bitmap") {                        // installBitmapButton: normal, focused|selected|disabled, style
            auto *b = qobject_cast<QPushButton *>(m);
            auto it = images.find(oa);
            if (!b || it == images.end()) return "1";
            c->bmp = oa; c->bmpDis = ob.split(FS).value(2); c->bmpStretch = has(oc, "STRETCH");
            b->setText(QString());
            if (!has(oc, "FRAME")) b->setFlat(true);
            b->setProperty("oodBmp", true);
            bmpPaint(*c);
            return "1";
        }
        if (c && op == "bitmapPos") {                     // setBitmapPosition: the picture's top left within the button
            c->bmpX = oa.toInt(); c->bmpY = ob.toInt(); c->bmpAt = true;
            bmpPaint(*c);
            return "1";
        }
        if (op == "backdrop") {                           // a picture behind the dialog or a control: TILE, STRETCH
            auto it = images.find(oa);
            if (it == images.end()) return "0";
            QWidget *t = c ? c->el : d->client;
            QPalette p = t->palette();
            const QPixmap px = has(ob, "STRETCH") ? it->second.second.scaled(t->size()) : it->second.second;
            p.setBrush(QPalette::Window, QBrush(px));
            t->setPalette(p);
            t->setAutoFillBackground(true);
            return "1";
        }
        if (op == "mouseSub") {                           // connect one mouse event of the dialog (id 0) or a control
            QWidget *host = mouseHostOf(d, id);
            if (!host) return "0";
            mouseHosts[host] = {d, id};
            d->mouseSubs.insert(QString::number(id) + "." + oa);
            if (oa == "MOUSEMOVE" || oa == "MOUSEHOVER") {   // moves with no button down reach a widget only when it tracks them
                host->setMouseTracking(true);
                for (auto *k : host->findChildren<QWidget *>()) k->setMouseTracking(true);
            }
            return "1";
        }
        if (op == "mouse") return mouseOp(d, id, oa, ob);
        if (op == "gdi") return gdi(d, c, oa, ob.split(FS), oc.split(FS));
        if (op == "tip") { el->setToolTip(oa); return "1"; }
        if (op == "exists") return "1";
        if (op == "kind") return c ? c->kind : "DIALOG";
        if (op == "getText") {
            if (!c) return d->win->windowTitle();
            if (auto *e = qobject_cast<QLineEdit *>(m)) return e->text();
            if (auto *t = qobject_cast<QPlainTextEdit *>(m)) return t->toPlainText().replace("\n", "\r\n");
            if (auto *cb = qobject_cast<QComboBox *>(m)) return cb->currentText();
            if (auto *lw = qobject_cast<QListWidget *>(m)) return lw->currentItem() ? lw->currentItem()->text() : "";
            return c->rawText;
        }
        if (op == "setText") {
            if (!c) { d->win->setWindowTitle(oa); return "1"; }
            if (auto *e = qobject_cast<QLineEdit *>(m)) { e->setText(oa); return "1"; }
            if (auto *t = qobject_cast<QPlainTextEdit *>(m)) { t->setPlainText(QString(oa).replace("\r\n", "\n")); return "1"; }
            if (auto *cb = qobject_cast<QComboBox *>(m)) { if (cb->isEditable()) cb->setEditText(oa); return "1"; }
            c->rawText = oa;
            if (auto *l = qobject_cast<QLabel *>(m)) l->setText(plain(oa));
            else if (auto *b = qobject_cast<QAbstractButton *>(m)) b->setText(oa);
            else if (auto *g = qobject_cast<QGroupBox *>(m)) g->setTitle(plain(oa));
            return "1";
        }
        if (op == "show") { el->show(); return "1"; }
        if (op == "hide") { el->hide(); return "1"; }
        if (op == "isVisible") return el->isVisibleTo(el->parentWidget() ? el->parentWidget() : el) && !el->isHidden() ? "1" : "0";
        if (op == "enable") { m->setEnabled(oa != "0"); return "1"; }
        if (op == "isEnabled") return m->isEnabled() ? "1" : "0";
        if (op == "focus") { m->setFocus(); return "1"; }
        if (op == "focusId") {
            QWidget *f = d->win->focusWidget();
            for (int cid : d->order) if (d->ctrls[cid].main == f) return QString::number(cid);
            return "0";
        }
        if (op == "rect") { const QRect r(el->mapToGlobal(QPoint(0, 0)), el->size()); return QString("%1 %2 %3 %4").arg(r.left()).arg(r.top()).arg(r.right() + 1).arg(r.bottom() + 1); }
        if (op == "clientRect") { QWidget *w = c ? el : d->client; return QString("0 0 %1 %2").arg(w->width()).arg(w->height()); }
        if (op == "origin") { const QPoint p = d->client->mapToGlobal(QPoint(0, 0)); return QString("%1 %2").arg(p.x()).arg(p.y()); }
        if (op == "move") {                               // a child of another control (setParent): in that one's client area
            QPoint at(oa.toInt(), ob.toInt());
            if (c && c->parentCtl) if (auto p = d->ctrls.find(c->parentCtl); p != d->ctrls.end()) at += clientOrigin(p->second.el);
            el->move(at);
            return "1";
        }
        if (op == "size") {                               // a drop-down combo keeps its own height (cy is its list's)
            if (!c) { d->client->setFixedSize(oa.toInt(), ob.toInt()); return "1"; }
            const bool dropDown = c->kind == "COMBO" && !has(c->opts, "SIMPLE");
            el->resize(oa.toInt(), dropDown ? el->height() : ob.toInt());
            return "1";
        }
        if (c && op == "setParent") {                    // SetParent(): shown on, and placed in, another control
            if (!d->ctrls.count(oa.toInt())) return "0";
            c->parentCtl = oa.toInt();
            el->raise();
            return "1";
        }
        if (c && op == "grandChild") {
            QWidget *keys = c->main;                      // an editable combo box keeps the focus and passes keys to its edit
            if (!keys->property("oodGrandChild").toBool()) {
                keys->setProperty("oodGrandChild", true);
                keys->installEventFilter(new GrandChild(d, id, oa == "1", keys));
            }
            return "1";
        }
        if (c && op == "tabStops") {                      // LB_SETTABSTOPS, in pixels
            auto *lw = qobject_cast<QListWidget *>(m);
            if (!lw) return "0";
            QList<int> s; for (const QString &t : oa.split(' ', Qt::SkipEmptyParts)) s << t.toInt();
            std::sort(s.begin(), s.end());
            c->tabStops = s;
            auto *dl = dynamic_cast<TabStopDelegate *>(lw->itemDelegate());
            if (!dl) { dl = new TabStopDelegate(lw); lw->setItemDelegate(dl); }
            dl->stops = s;
            lw->viewport()->update();
            return "1";
        }
        if (op == "closeBox") { d->noClose = oa == "0"; return "1"; }
        if (op == "top") { d->win->raise(); return "1"; }
        if (op == "default") {
            if (auto old = d->ctrls.find(d->defId); old != d->ctrls.end()) if (auto *b = qobject_cast<QPushButton *>(old->second.main)) b->setDefault(false);
            d->defId = oa.toInt();
            if (auto nw = d->ctrls.find(d->defId); nw != d->ctrls.end()) if (auto *b = qobject_cast<QPushButton *>(nw->second.main)) b->setDefault(true);
            return "1";
        }
        if (op == "textSize") { const QSize s = QFontMetrics(m->font()).size(0, oa); return QString("%1 %2").arg(s.width()).arg(s.height()); }
        if (op == "sel") { if (auto *e = qobject_cast<QLineEdit *>(m)) { const int s = e->selectionStart() < 0 ? e->cursorPosition() : e->selectionStart(); return QString("%1 %2").arg(s + 1).arg(s + e->selectedText().size() + 1); } return "1 1"; }
        if (op == "replaceSel") { if (auto *e = qobject_cast<QLineEdit *>(m)) { e->insert(oa); c->modified = true; } return "1"; }
        if (op == "line") { if (auto *t = qobject_cast<QPlainTextEdit *>(m)) return t->toPlainText().split('\n').value(oa.toInt() - 1); if (auto *e = qobject_cast<QLineEdit *>(m)) return oa == "1" ? e->text() : ""; return ""; }
        if (op == "cue") { if (auto *e = qobject_cast<QLineEdit *>(m)) e->setPlaceholderText(oa); return "1"; }
        auto *lw = qobject_cast<QListWidget *>(m);
        auto *cb = qobject_cast<QComboBox *>(m);
        if (op == "add" || op == "insert") {
            const QString text = op == "add" ? oa : ob;
            const int at = op == "add" ? -1 : oa.toInt();
            if (lw) { if (at < 0 || at >= lw->count()) { lw->addItem(text); return QString::number(lw->row(lw->findItems(text, Qt::MatchExactly).value(0))); } lw->insertItem(at, text); return QString::number(at); }
            if (cb) {
                // Qt makes the first item added the current one.  Windows leaves an editable combo's edit as it
                // was, and so does the page's datalist input; a drop-down list keeps Qt's way, as the page's <select> does.
                const int was = cb->currentIndex();
                const QString edit = cb->currentText();
                QSignalBlocker hush(cb);
                int r;
                if (at < 0 || at >= cb->count()) { cb->addItem(text); r = cb->findText(text); } else { cb->insertItem(at, text); r = at; }
                if (was < 0 && cb->isEditable()) { cb->setCurrentIndex(-1); cb->setEditText(edit); }
                return QString::number(r);
            }
            return "-1";
        }
        if (op == "itemText") { const int i = oa.toInt(); if (lw) return lw->item(i) ? lw->item(i)->text() : ""; if (cb) return cb->itemText(i); return ""; }
        if (op == "find") {
            const bool exact = arg(5) == "1";
            const int start = ob.toInt();
            const int n = lw ? lw->count() : cb ? cb->count() : 0;
            for (int k = 1; k <= n; ++k) {
                const int i = (start + k + n) % n;
                const QString t = lw ? lw->item(i)->text() : cb->itemText(i);
                if (exact ? t.compare(oa, Qt::CaseInsensitive) == 0 : t.startsWith(oa, Qt::CaseInsensitive)) return QString::number(i);
            }
            return "-1";
        }
        if (op == "selItems") {
            QStringList out;
            if (lw) for (int i = 0; i < lw->count(); ++i) if (lw->item(i)->isSelected()) out << QString::number(i + 1);
            return out.join(' ');
        }
        if (op == "selectText") {
            if (lw) { auto items = lw->findItems(oa, Qt::MatchStartsWith); const int i = items.isEmpty() ? -1 : lw->row(items[0]); lw->setCurrentRow(i); return QString::number(i); }
            if (cb) { const int i = cb->findText(oa, Qt::MatchStartsWith); if (i >= 0) cb->setCurrentIndex(i); else if (cb->isEditable()) cb->setEditText(oa); return QString::number(i); }
            return "-1";
        }
        fprintf(stderr, "oodqt: op not implemented yet: %s\n", qPrintable(op));
        return "";
    }
    fprintf(stderr, "oodqt: message not implemented yet: %s\n", qPrintable(name));
    return "";
}

/*======================================================================*/
/* Steps player: the browser harness's .steps files, against Qt widgets */
/*======================================================================*/
struct Steps {
    QStringList lines;
    int at = 0;
    QElapsedTimer since;
    qint64 sleepUntil = -1;
    QString shots;
    QTimer timer;
} *steps = nullptr;

QWidget *topDialog() {
    QWidget *best = nullptr;
    for (auto &kv : dialogs) if (kv.second->win->isVisible() && kv.second->win->isWindow()) best = kv.second->win;   // the newest visible window
    if (QWidget *m = QApplication::activeModalWidget()) if (m->objectName() == "ood-msgbox") return m;
    return best;
}

QString widgetText(QWidget *w) {
    if (auto *b = qobject_cast<QAbstractButton *>(w)) return plain(b->text());
    if (auto *l = qobject_cast<QLabel *>(w)) return l->text();
    if (auto *g = qobject_cast<QGroupBox *>(w)) return g->title();
    return QString();
}

/* Playwright text=X, unquoted: case-insensitive substring; an exact match is preferred. */
template <typename T, typename F> T matchText(const QList<T> &items, const QString &want, F text) {
    for (T i : items) if (text(i) == want) return i;
    for (T i : items) if (text(i).contains(want, Qt::CaseInsensitive)) return i;
    return nullptr;
}

/* Selectors used by the .steps files:
 *   SCOPE >> text=TEXT   SCOPE input[.ood-edit]   SCOPE .ood-check input   SCOPE textarea   SCOPE select
 *   SCOPE .ood-static[:not(:empty)]
 * SCOPE is .ood-dlg (the newest visible dialog), .ood-msgbox, .ood-menubar or .ood-menu. */
QTreeWidgetItem *pendingItem = nullptr;               // the row or node a .ood-lv / .ood-tv selector found
int pendingCol = -1;                                   // the header a .ood-lv th selector found
bool pendingCheck = false;                             // the row's check box, not the row
int pendingCell = -1;                                  // the cell a .ood-lv tbody tr >> nth=R >> td >> nth=C selector found
int pendingTab = -1;                                   // the tab a .ood-tabbtn selector found

QWidget *scopeRoot = nullptr;                          // set while a .ood-child selector searches one child
QObject *find(const QString &selector, QString *why) {
    pendingCheck = false; pendingCell = -1;
    pendingItem = nullptr; pendingTab = -1; pendingCol = -1;   // set again by the selector that finds a row, node, tab or header
    QString sel = selector.trimmed();
    QString scope = sel.section(' ', 0, 0);
    QString rest = sel.section(' ', 1).trimmed();
    if (scope != ".ood-dlg" && scope != ".ood-child" && scope != ".ood-menubar" && scope != ".ood-menu" && scope != ".ood-msgbox") { rest = sel; scope = ".ood-dlg"; }
    if (rest.startsWith(">>")) rest = rest.mid(2).trimmed();
    if (scope == ".ood-dlg" && !scopeRoot) {              // every shown dialog, the newest first, as the page's .ood-dlg elements
        QWidget *m = QApplication::activeModalWidget();
        if (!(m && m->objectName() == "ood-msgbox")) {
            for (auto it = dialogs.rbegin(); it != dialogs.rend(); ++it) {
                QWidget *win = it->second->win;
                if (!win->isVisible() || !win->isWindow()) continue;
                if (rest.isEmpty()) return win;               // the bare .ood-dlg: the newest shown dialog
                QString no;
                scopeRoot = win;
                QObject *o = find(".ood-dlg " + rest, &no);
                scopeRoot = nullptr;
                if (o) return o;
                *why = no;
            }
            if (why->isEmpty()) *why = "no visible dialog";
            return nullptr;
        }
    }
    if (scope == ".ood-child") {                           // the shown child dialogs, each searched as a dialog
        QWidget *top = topDialog();
        for (QWidget *ch : top ? top->findChildren<QWidget *>("ood-child") : QList<QWidget *>()) {
            if (!ch->isVisible()) continue;
            QString no;
            scopeRoot = ch;
            if (rest.isEmpty()) return ch;
            QObject *o = find(".ood-dlg " + rest, &no);
            scopeRoot = nullptr;
            if (o) return o;
        }
        *why = "no shown child dialog has " + rest; return nullptr;
    }
    QWidget *root = scopeRoot ? scopeRoot : topDialog();
    if (scope == ".ood-msgbox") {
        root = nullptr;
        for (QWidget *w : QApplication::topLevelWidgets()) if (w->objectName() == "ood-msgbox" && w->isVisible()) root = w;
        if (!root) { *why = "no message box"; return nullptr; }
    }
    if (scope == ".ood-menubar") {
        if (!root) { *why = "no dialog"; return nullptr; }
        auto *bar = root->findChild<QMenuBar *>("ood-menubar");
        if (!bar) { *why = "no menu bar"; return nullptr; }
        if (rest.startsWith("text=")) if (QAction *a = matchText(bar->actions(), rest.mid(5), [](QAction *x) { return plain(x->text()); })) return a;
        *why = "no menu bar item " + rest; return nullptr;
    }
    if (scope == ".ood-menu") {
        for (QWidget *w : QApplication::topLevelWidgets()) if (auto *m = qobject_cast<QMenu *>(w)) if (m->isVisible())
            if (rest.startsWith("text=")) if (QAction *a = matchText(m->actions(), rest.mid(5), [](QAction *x) { return plain(x->text()); })) return a;
        *why = "no open menu item " + rest; return nullptr;
    }
    if (!root) { *why = "no visible dialog"; return nullptr; }
    if (QRegularExpressionMatch m = QRegularExpression(R"(^\.ood-lv tbody tr >> nth=(\d+)(?: >> td >> nth=(\d+))?$)").match(rest); m.hasMatch()) {
        for (auto *tw : root->findChildren<QTreeWidget *>("ood-lv")) {    // a row, or one cell of it, of the first list-view
            if (!tw->isVisible()) continue;
            const int row = m.captured(1).toInt();
            if (row >= tw->topLevelItemCount()) break;
            pendingItem = tw->topLevelItem(row);
            pendingCell = m.captured(2).isEmpty() ? -1 : m.captured(2).toInt();
            return tw;
        }
        *why = "no list-view row " + m.captured(1); return nullptr;
    }
    if (QRegularExpressionMatch m = QRegularExpression(R"(^\.(ood-[a-z]+) >> nth=(\d+)$)").match(rest); m.hasMatch()) {
        QList<QWidget *> shown;                           // the Nth of a kind, in the order the page has them
        for (auto *w : root->findChildren<QWidget *>(m.captured(1))) if (w->isVisible()) shown << w;
        const int n = m.captured(2).toInt();
        if (n < shown.size()) return shown[n];
        *why = "no ." + m.captured(1) + " number " + m.captured(2); return nullptr;
    }
    if (QRegularExpressionMatch m = QRegularExpression(R"(^\.ood-lv tr:nth-child\((\d+)\)( \.ood-lvchk)?$)").match(rest); m.hasMatch()) {
        const int row = m.captured(1).toInt() - 1;
        for (auto *tw : root->findChildren<QTreeWidget *>("ood-lv")) {
            if (!tw->isVisible() || row < 0 || row >= tw->topLevelItemCount()) continue;
            pendingItem = tw->topLevelItem(row); pendingCheck = !m.captured(2).isEmpty();
            return tw;
        }
        *why = "no list-view row " + m.captured(1); return nullptr;
    }
    if (rest.startsWith(".ood-lv th")) {                  // a report view's column header
        const QString want = rest.section("text=", 1);
        pendingItem = nullptr; pendingTab = -1; pendingCol = -1;
        for (auto *tw : root->findChildren<QTreeWidget *>("ood-lv")) {
            if (!tw->isVisible() || tw->isHeaderHidden()) continue;
            QTreeWidgetItem *h = tw->headerItem();
            for (int k = 0; k < tw->columnCount(); ++k) if (h->text(k) == want) { pendingCol = k; return tw; }
            for (int k = 0; k < tw->columnCount(); ++k) if (h->text(k).contains(want, Qt::CaseInsensitive)) { pendingCol = k; return tw; }
        }
        *why = "no column header " + want; return nullptr;
    }
    if (rest == ".ood-client" || rest == ".ood-title") {   // the client area; the title bar is outside the window, the player moves above it
        for (auto &kv : dialogs) if (kv.second->win == root) return rest == ".ood-client" ? kv.second->client : (QWidget *)kv.second->win;
        *why = "no dialog for " + rest; return nullptr;
    }
    if (rest.startsWith(".ood-mc")) {                     // a month calendar; -next and -prev its arrows, -foot its Today line
        for (auto *box : root->findChildren<QWidget *>("ood-mc")) {
            if (!box->isVisible()) continue;
            if (rest == ".ood-mc") return box;
            const char *name = rest == ".ood-mc-next" ? "qt_calendar_nextmonth" : rest == ".ood-mc-prev" ? "qt_calendar_prevmonth" : rest == ".ood-mc-foot" ? "ood-mc-foot" : "";
            if (QWidget *w = box->findChild<QWidget *>(name)) return w;
        }
        *why = "no month calendar part " + rest; return nullptr;
    }
    if (rest.startsWith(".ood-image")) {                  // a static image; " img" when it shows a picture
        for (auto *l : root->findChildren<QLabel *>("ood-image")) {
            if (!l->isVisible()) continue;
            if (!rest.contains(" img") || !l->pixmap().isNull()) return l;
        }
        *why = "no image shown"; return nullptr;
    }
    if (rest.startsWith("button.ood-bmp")) {              // a bitmap button with its picture
        for (auto *b : root->findChildren<QPushButton *>()) if (b->isVisible() && b->property("oodBmp").toBool()) return b;
        *why = "no bitmap button"; return nullptr;
    }
    if (rest.startsWith("button.ood-def")) {              // the default push button
        for (auto *b : root->findChildren<QPushButton *>()) if (b->isVisible() && b->isDefault()) return b;
        *why = "no default button"; return nullptr;
    }
    if (rest.startsWith("button:text-is(\"")) {           // a push button whose whole text is this
        const QString want = rest.section('"', 1, 1);
        for (auto *b : root->findChildren<QPushButton *>()) if (b->isVisible() && plain(b->text()) == want) return b;
        *why = "no button with exactly " + want; return nullptr;
    }
    if (rest.startsWith(".ood-lv") || rest.startsWith(".ood-tv") || rest.startsWith(".ood-tabbtn")) {
        const QString want = rest.contains("text=") ? rest.section("text=", 1) : QString();
        pendingItem = nullptr; pendingTab = -1; pendingCol = -1;
        if (rest.startsWith(".ood-tabbtn")) {
            for (auto *bar : root->findChildren<QTabBar *>("ood-tabstrip")) {
                if (!bar->isVisible()) continue;
                QList<int> idx; for (int k = 0; k < bar->count(); ++k) idx << k;
                for (int k : idx) if (plain(bar->tabText(k)) == want) { pendingTab = k; return bar; }
                for (int k : idx) if (plain(bar->tabText(k)).contains(want, Qt::CaseInsensitive)) { pendingTab = k; return bar; }
            }
            *why = "no tab " + want; return nullptr;
        }
        const QString name = rest.startsWith(".ood-lv") ? "ood-lv" : "ood-tv";
        for (auto *tw : root->findChildren<QTreeWidget *>(name)) {
            if (!tw->isVisible()) continue;
            if (want.isEmpty()) return tw;
            QList<QTreeWidgetItem *> shown;
            for (QTreeWidgetItemIterator it(tw); *it; ++it) {
                bool open = true;
                for (QTreeWidgetItem *p = (*it)->parent(); p; p = p->parent()) if (!p->isExpanded()) open = false;
                if (open) shown << *it;
            }
            auto rowText = [](QTreeWidgetItem *x) { QStringList t; for (int k = 0; k < x->columnCount(); ++k) t << x->text(k); return t; };
            for (auto *x : shown) if (rowText(x).contains(want)) { pendingItem = x; return tw; }
            for (auto *x : shown) for (const QString &t : rowText(x)) if (t.contains(want, Qt::CaseInsensitive)) { pendingItem = x; return tw; }
        }
        *why = "no " + name + " item " + want; return nullptr;
    }
    if (rest.startsWith("text=")) {
        const QString want = rest.mid(5);
        QList<QWidget *> shown;
        for (QWidget *w : root->findChildren<QWidget *>()) if (w->isVisible() && !widgetText(w).isEmpty()) shown << w;
        if (QWidget *w = matchText(shown, want, [](QWidget *x) { return widgetText(x); })) return w;
        if (root->isWindow() && root->windowTitle().contains(want, Qt::CaseInsensitive)) return root;   // the page draws the caption as an element
        for (const char *in : {".ood-lv >> text=", ".ood-tv >> text=", ".ood-tabbtn >> text="}) {   // the page's rows, nodes and tabs are elements too
            QString no;
            if (QObject *o = find(scope + " " + in + want, &no)) return o;
        }
        *why = "no visible widget with text " + want; return nullptr;
    }
    if (rest == "> .ood-client > button") {               // a push button of the dialog itself, not of a child
        for (auto *b : root->findChildren<QPushButton *>()) {
            QWidget *owner = b->parentWidget() ? b->parentWidget()->parentWidget() : nullptr;   // client, then the dialog
            if (b->isVisible() && owner == root) return b;
        }
        *why = "no button in the dialog's client"; return nullptr;
    }
    if (rest.startsWith(".ood-ud")) {                      // an up-down: the box, or its up (first) or down (last) button
        for (auto *u : root->findChildren<QWidget *>("ood-ud")) {
            if (!u->isVisible()) continue;
            const auto bs = u->findChildren<QToolButton *>();
            if (rest.contains("button:first-child") && !bs.isEmpty()) return bs.first();
            if (rest.contains("button:last-child") && !bs.isEmpty()) return bs.last();
            return u;
        }
        *why = "no up-down"; return nullptr;
    }
    if (rest.startsWith("input[type=date]") || rest.startsWith("input[type=time]")) {
        for (auto *e : root->findChildren<QDateTimeEdit *>()) if (e->isVisible()) return e;
        *why = "no date-time picker"; return nullptr;
    }
    QList<QWidget *> cands;
    if (rest.startsWith("input") && !rest.contains("ood-check")) {   // an edit: not a picker's or a combo's own line; [readonly] or :not([readonly])
        const bool ro = rest.startsWith("input[readonly]"), rw = rest.startsWith("input:not([readonly])");
        for (auto *e : root->findChildren<QLineEdit *>()) {
            if (qobject_cast<QAbstractSpinBox *>(e->parentWidget()) || qobject_cast<QComboBox *>(e->parentWidget())) continue;
            if ((ro && !e->isReadOnly()) || (rw && e->isReadOnly())) continue;
            cands << e;
        }
    }
    else if (rest.contains(".ood-check")) for (auto *b : root->findChildren<QAbstractButton *>()) { if (qobject_cast<QCheckBox *>(b) || qobject_cast<QRadioButton *>(b)) cands << b; }
    else if (rest.startsWith(".ood-track")) for (auto *s : root->findChildren<QSlider *>()) cands << s;   // a track bar
    else if (rest.startsWith("textarea")) for (auto *t : root->findChildren<QPlainTextEdit *>()) cands << t;
    else if (rest.startsWith("select[size]")) { for (auto *l : root->findChildren<QListWidget *>()) cands << l; }   // a list box
    else if (rest.startsWith("select")) { for (auto *c : root->findChildren<QComboBox *>()) cands << c; for (auto *l : root->findChildren<QListWidget *>()) cands << l; }
    else if (rest.startsWith(".ood-static")) {
        const bool nonEmpty = rest.contains(":not(:empty)");
        for (auto *l : root->findChildren<QLabel *>()) if (l->objectName() != "ood-todo" && (!nonEmpty || !l->text().isEmpty())) cands << l;
    }
    for (QWidget *w : cands) if (w->isVisible()) return w;
    *why = "nothing matches " + rest; return nullptr;
}

QString valueOf(QObject *o) {
    if (auto *e = qobject_cast<QLineEdit *>(o)) return e->text();
    if (auto *t = qobject_cast<QPlainTextEdit *>(o)) return t->toPlainText();
    if (auto *c = qobject_cast<QComboBox *>(o)) return c->currentText();
    if (auto *w = qobject_cast<QWidget *>(o)) return widgetText(w);
    return QString();
}

QString markedState;                                   // what `mark SELECTOR` saw, for `expect moved`
QString pictureState(QObject *o) {                     // a bitmap button's picture and where it sits, or a widget's text
    for (auto &kv : dialogs) for (auto &cc : kv.second->ctrls) if (cc.second.main == o)
        return cc.second.bmp + "@" + QString::number(cc.second.bmpX) + "," + QString::number(cc.second.bmpY);
    return o ? valueOf(o) : QString();
}
/* The browser checks the designer's and the suite's steps use, translated to the same
 * question about the Qt widgets.  Anything else stays a failure that asks for a .qt.steps. */
QString dialogText(QWidget *root) {                     // what innerText would show
    QStringList out;
    for (QWidget *w : root->findChildren<QWidget *>()) {
        if (!w->isVisible()) continue;
        if (auto *tw = qobject_cast<QTreeWidget *>(w)) {
            for (QTreeWidgetItemIterator it(tw); *it; ++it) for (int k = 0; k < (*it)->columnCount(); ++k) out << (*it)->text(k);
        } else if (auto *bar = qobject_cast<QTabBar *>(w)) {
            for (int k = 0; k < bar->count(); ++k) out << plain(bar->tabText(k));
        } else if (!qobject_cast<QLineEdit *>(w) && !qobject_cast<QPlainTextEdit *>(w)) {
            const QString t = widgetText(w);
            if (!t.isEmpty()) out << t;
        }
    }
    return out.join('\n');
}
/* -> true and sets got when the step is one of the translated forms; ok says whether it holds */
bool translatedExpect(const QString &rest, bool *ok, QString *got, QString *why) {
    static const QRegularExpression value(R"(^document\.querySelector\('([^']+)'\)\.(value|textContent|title)(?:\.trim\(\))? ==> (.*)$)");
    static const QRegularExpression includes(R"(^document\.querySelector\('([^']+)'\)\.innerText\.includes\('([^']*)'\) ==> (\w+)$)");
    static const QRegularExpression rows(R"(^(?:\[\.\.\.)?document\.querySelectorAll\('([^']+) tbody tr'\)\]?\.length ==> (\d+)$)");
    static const QRegularExpression shown(R"(^\[\.\.\.document\.querySelectorAll\('([^']+) textarea'\)\]\.map\(e=>e\.offsetParent!==null\)\.join\(\) ==> (.*)$)");
    QRegularExpressionMatch m;
    static const QRegularExpression valueIs(R"(^document\.querySelector\('([^']+)'\)\.value === '([^']*)' ==> (\w+)$)");
    static const QRegularExpression firstCell(R"(^document\.querySelector\('([^']*)\.ood-lv tbody tr td'\)\.textContent ==> (.*)$)");
    static const QRegularExpression barsFilled(R"(^\[\.\.\.document\.querySelectorAll\('\.ood-progress div'\)\]\.every\(b => parseFloat\(b\.style\.(?:height|width)\) > 0\) ==> (\w+)$)");
    if ((m = barsFilled.match(rest)).hasMatch()) {        // every progress bar shows some progress
        QWidget *root = topDialog();
        bool all = root != nullptr;
        for (auto *p : root ? root->findChildren<QProgressBar *>() : QList<QProgressBar *>()) all = all && p->value() > p->minimum();
        *got = all ? "True" : "False";
        *ok = (*got).compare(m.captured(1), Qt::CaseInsensitive) == 0;
        return true;
    }
    static const QRegularExpression inked(R"(^\(\(\) => \{ const cv = .*canvas\.ood-gdi.*return n > (\d+); \}\)\(\) ==> (\w+)$)");
    static const QRegularExpression inkAt(R"(^\(\(\) => \{ const cv = .*canvas\.ood-gdi.*getImageData\((\d+), (\d+), 1, 1\)\.data; return p\[3\] > 0; \}\)\(\) ==> (\w+)$)");
    static const QRegularExpression rexxErrors(R"(^\(window\.oodOut\.join\(''\)\.match\(.*Error.*\) ?\|\| ?\[\]\)\.length ==> 0$)");
    if ((m = inked.match(rest)).hasMatch() || (m = inkAt.match(rest)).hasMatch()) {   // the largest drawing layer
        GdiLayer *big = nullptr;
        for (auto &kv : dialogs) for (auto &g : kv.second->gdi) {
            auto *l = static_cast<GdiLayer *>(g.second);
            if (l->isVisible() && (!big || l->img.width() * l->img.height() > big->img.width() * big->img.height())) big = l;
        }
        bool yes = false;
        if (big && m.lastCapturedIndex() == 2) {           // inked pixels: of the largest layer, or of all when the step sums them
            long count = 0;
            const bool sum = rest.contains("for (const c of cv)");
            for (auto &kv : dialogs) for (auto &g : kv.second->gdi) {
                auto *l = static_cast<GdiLayer *>(g.second);
                if (!l->isVisible() || (!sum && l != big)) continue;
                for (int y = 0; y < l->img.height(); ++y) for (int x = 0; x < l->img.width(); ++x) count += qAlpha(l->img.pixel(x, y)) ? 1 : 0;
            }
            yes = count > m.captured(1).toLong();
        } else if (big) {
            const int x = m.captured(1).toInt(), y = m.captured(2).toInt();
            yes = big->img.valid(x, y) && qAlpha(big->img.pixel(x, y)) > 0;
        }
        *got = big ? (yes ? "True" : "False") : "no drawing layer";
        *ok = (*got).compare(m.captured(m.lastCapturedIndex()), Qt::CaseInsensitive) == 0;
        return true;
    }
    if (rexxErrors.match(rest).hasMatch()) {             // the runner fails a test on any Rexx error on stderr
        *got = "0"; *ok = true; return true;
    }
    static const QRegularExpression options(R"(^\[\.\.\.document\.querySelectorAll\('([^']+) select\[size\] option'\)\]\.map\(o => o\.textContent\)\.(includes\('([^']*)'\)|join\(','\)) ==> (.*)$)");
    static const QRegularExpression wizardButtons(R"(^\[\.\.\.document\.querySelectorAll\('\.ood-dlg:not\(\.ood-child\) > \* button\.ood-c, .*\.join\(','\) ==> (.*)$)");
    static const QRegularExpression buttonDisabled(R"(^\[\.\.\.document\.querySelectorAll\('\.ood-dlg button\.ood-c'\)\]\.find\(b => b\.textContent\.trim\(\) === '([^']*)'\)\.disabled ==> (\w+)$)");
    if ((m = options.match(rest)).hasMatch()) {           // a list box's items
        auto *lw = qobject_cast<QListWidget *>(find(m.captured(1) + " select[size]", why));
        QStringList items;
        for (int i = 0; lw && i < lw->count(); ++i) items << lw->item(i)->text();
        if (m.captured(2).startsWith("includes")) *got = items.contains(m.captured(3)) ? "True" : "False";
        else *got = items.join(',');
        *ok = (*got).compare(m.captured(4), m.captured(2).startsWith("includes") ? Qt::CaseInsensitive : Qt::CaseSensitive) == 0;
        return true;
    }
    if ((m = wizardButtons.match(rest)).hasMatch()) {     // the dialog's own push buttons, not a page's: text, (h) hidden, (d) disabled
        QWidget *root = topDialog();
        QStringList out;
        for (auto *b : root ? root->findChildren<QPushButton *>() : QList<QPushButton *>()) {
            bool inChild = false;
            for (QWidget *p = b->parentWidget(); p && p != root; p = p->parentWidget()) if (p->objectName() == "ood-child") inChild = true;
            if (inChild) continue;
            out << plain(b->text()) + (b->isHidden() ? "(h)" : "") + (b->isEnabled() ? "" : "(d)");
        }
        *got = out.join(',');
        *ok = *got == m.captured(1);
        return true;
    }
    if ((m = buttonDisabled.match(rest)).hasMatch()) {
        QPushButton *hit = nullptr;
        for (auto &kv : dialogs) if (kv.second->win->isVisible()) for (auto *b : kv.second->win->findChildren<QPushButton *>()) if (plain(b->text()) == m.captured(1)) hit = b;
        *got = hit ? (hit->isEnabled() ? "False" : "True") : "no button";
        *ok = (*got).compare(m.captured(2), Qt::CaseInsensitive) == 0;
        return true;
    }
    static const QRegularExpression bmpUrl(R"(^document\.querySelector\('button\.ood-bmp'\)\.style\.backgroundImage\.startsWith\('url\("([^"]+)'\) ==> (\w+)$)");
    static const QRegularExpression imgShown(R"(^document\.querySelector\('([^']*)\.ood-image img'\)\.naturalWidth > 0 ==> (\w+)$)");
    if ((m = bmpUrl.match(rest)).hasMatch()) {            // the bitmap button's picture came as this kind of data URL
        bool yes = false;
        for (auto &kv : dialogs) for (auto &cc : kv.second->ctrls) {
            auto it = images.find(cc.second.bmp);
            if (it != images.end() && cc.second.kind == "BUTTON" && (it->second.first + ",").startsWith(m.captured(1)) && !it->second.second.isNull()) yes = true;
        }
        *got = yes ? "True" : "False";
        *ok = (*got).compare(m.captured(2), Qt::CaseInsensitive) == 0;
        return true;
    }
    if ((m = imgShown.match(rest)).hasMatch()) {
        auto *l = qobject_cast<QLabel *>(find(m.captured(1) + ".ood-image img", why));
        *got = l && l->pixmap().width() > 0 ? "True" : "False";
        *ok = (*got).compare(m.captured(2), Qt::CaseInsensitive) == 0;
        return true;
    }
    static const QRegularExpression enabledNamed(R"(^\[\.\.\.document\.querySelectorAll\('\.ood-dlg button\.ood-c'\)\]\.filter\(x => x\.textContent\.trim\(\) === '([^']*)' && !x\.disabled\)\.length ==> (\d+)$)");
    if ((m = enabledNamed.match(rest)).hasMatch()) {      // enabled push buttons with exactly this text
        int count = 0;
        for (auto &kv : dialogs) if (kv.second->win->isVisible()) for (auto *b : kv.second->win->findChildren<QPushButton *>())
            if (b->isVisible() && b->isEnabled() && plain(b->text()) == m.captured(1)) ++count;
        *got = QString::number(count);
        *ok = *got == m.captured(2);
        return true;
    }
    static const QRegularExpression lvRowsAll(R"(^\[\.\.\.document\.querySelectorAll\('\.ood-lv'\)\]\.map\(l => l\.querySelectorAll\('tbody tr'\)\.length\)\.join\(','\) ==> (.*)$)");
    static const QRegularExpression lvFirstRow(R"(^\[\.\.\.document\.querySelectorAll\('\.ood-lv'\)\]\[(\d+)\]\.querySelector\('tbody tr'\)\.innerText\.replace\(/\\s\+/g, ' '\)\.trim\(\) ==> (.*)$)");
    static const QRegularExpression lvCell0(R"(^document\.querySelector\('\.ood-lv tbody tr'\)\.cells\[(\d+)\]\.textContent ==> (.*)$)");
    static const QRegularExpression bodyCursor(R"(^document\.body\.style\.cursor ==> (.*)$)");
    static const QRegularExpression bodyCursorUrl(R"(^document\.body\.style\.cursor\.startsWith\('url\("([^']*)'\) ==> (\w+)$)");
    static const QRegularExpression scrollTop(R"(^document\.querySelector\('([^']+) textarea'\)\.scrollTop ==> (\d+)$)");
    static const QRegularExpression scrollTopBetween(R"(^\(\(\) => \{ const t = document\.querySelector\('([^']+) textarea'\)\.scrollTop; return t > (\d+) && t < (\d+); \}\)\(\) ==> (\w+)$)");
    auto lvs = [] {                                       // the shown list-views, in the page's order
        QList<QTreeWidget *> out;
        QWidget *root = topDialog();
        for (auto *t : root ? root->findChildren<QTreeWidget *>("ood-lv") : QList<QTreeWidget *>()) if (t->isVisible()) out << t;
        return out;
    };
    auto rowText = [](QTreeWidgetItem *it) { QStringList s; for (int k = 0; k < it->columnCount(); ++k) s << it->text(k); return s.join(' ').simplified(); };
    auto pixelsDown = [](const QString &scope, QString *why) -> int {   // a multi-line edit's scrollTop, in pixels as the page counts it
        auto *t = qobject_cast<QPlainTextEdit *>(find(scope + " textarea", why));
        if (!t) return -1;
        return t->verticalScrollBar()->value() * QFontMetrics(t->font()).lineSpacing();
    };
    if ((m = lvRowsAll.match(rest)).hasMatch()) {
        QStringList n; for (auto *t : lvs()) n << QString::number(t->topLevelItemCount());
        *got = n.join(','); *ok = *got == m.captured(1); return true;
    }
    if ((m = lvFirstRow.match(rest)).hasMatch()) {
        const auto all = lvs(); const int k = m.captured(1).toInt();
        *got = k < all.size() && all[k]->topLevelItemCount() ? rowText(all[k]->topLevelItem(0)) : "no row";
        *ok = *got == m.captured(2); return true;
    }
    if ((m = lvCell0.match(rest)).hasMatch()) {
        const auto all = lvs();
        *got = !all.isEmpty() && all[0]->topLevelItemCount() ? all[0]->topLevelItem(0)->text(m.captured(1).toInt()) : "no row";
        *ok = *got == m.captured(2); return true;
    }
    if ((m = bodyCursorUrl.match(rest)).hasMatch()) {    // the cursor is a picture Rexx sent, of this kind
        auto it = images.find(cursorName);
        const bool yes = it != images.end() && (it->second.first + ",").startsWith(m.captured(1));
        *got = yes ? "True" : "False (" + cursorName + ")"; *ok = (*got).compare(m.captured(2), Qt::CaseInsensitive) == 0; return true;
    }
    if ((m = bodyCursor.match(rest)).hasMatch()) {
        *got = cursorName; *ok = *got == m.captured(1); return true;
    }
    if ((m = scrollTop.match(rest)).hasMatch()) {
        *got = QString::number(pixelsDown(m.captured(1), why)); *ok = *got == m.captured(2); return true;
    }
    if ((m = scrollTopBetween.match(rest)).hasMatch()) {
        const int t = pixelsDown(m.captured(1), why);
        *got = t > m.captured(2).toInt() && t < m.captured(3).toInt() ? "True" : "False";
        if (*got == "False") *got += " (" + QString::number(t) + " px)";
        *ok = (*got).compare(m.captured(4), Qt::CaseInsensitive) == 0; return true;
    }
    static const QRegularExpression overCell(R"(^\(\(\) => \{ const e = document\.querySelector\('\.ood-dlg ([^']+)'\); const r = e\.getBoundingClientRect\(\), td = document\.querySelectorAll\('\.ood-lv tbody tr'\)\[(\d+)\]\.children\[(\d+)\]\.getBoundingClientRect\(\); return .*\}\)\(\) ==> (\w+)$)");
    static const QRegularExpression cellText(R"(^document\.querySelectorAll\('\.ood-lv tbody tr'\)\[(\d+)\]\.children\[(\d+)\]\.textContent ==> (.*)$)");
    static const QRegularExpression hiddenOne(R"(^document\.querySelector\('\.ood-dlg ([^']+)'\)(?:\.hidden(?: \|\| document\.querySelector\('\.ood-dlg [^']+'\)\.closest\('\[hidden\]'\) !== null)?|\.closest\('\[hidden\]'\) !== null) ==> (\w+)$)");
    static const QRegularExpression firstOptionJson(R"(^JSON\.stringify\(\[\.\.\.document\.querySelectorAll\('\.ood-dlg'\)\]\.pop\(\)\.querySelector\('select option'\)\.textContent\) ==> (.*)$)");
    static const QRegularExpression tabbedUnder(R"(^\(\(\) => \{ const d = \[\.\.\.document\.querySelectorAll\('\.ood-dlg'\)\]\.pop\(\), o = d\.querySelector\('select option'\);.*o\.label\.indexOf\('([^']+)'\).*x\.textContent\.trim\(\) === '([^']+)'\).*return Math\.abs\(at - want\) < (\d+); \}\)\(\) ==> (\w+)$)");
    auto inPlace = [](const QString &sel) -> QWidget * {  // the page's in-place editor: an edit, or a drop-down combo
        QWidget *root = topDialog();
        if (!root) return nullptr;
        if (sel.startsWith("select")) { for (auto *cb : root->findChildren<QComboBox *>()) return cb; return nullptr; }
        if (sel.contains("[list]")) { for (auto *cb : root->findChildren<QComboBox *>()) if (cb->isEditable()) return cb; return nullptr; }   // an editable combo: an edit with a datalist
        for (auto *e : root->findChildren<QLineEdit *>()) {
            if (qobject_cast<QAbstractSpinBox *>(e->parentWidget()) || qobject_cast<QComboBox *>(e->parentWidget())) continue;
            return e;
        }
        return nullptr;
    };
    auto firstLv = [] { QWidget *root = topDialog(); return root ? root->findChild<QTreeWidget *>("ood-lv") : nullptr; };
    if ((m = overCell.match(rest)).hasMatch()) {          // the editor lies over the cell and has the focus
        QWidget *e = inPlace(m.captured(1));
        QTreeWidget *tw = firstLv();
        QTreeWidgetItem *it = tw ? tw->topLevelItem(m.captured(2).toInt()) : nullptr;
        if (!e || !it) { *got = "no editor or no row"; *ok = false; return true; }
        QRect r = tw->visualItemRect(it);
        const int col = m.captured(3).toInt();
        r.setLeft(tw->columnViewportPosition(col)); r.setWidth(tw->columnWidth(col));
        const QRect cell(tw->viewport()->mapToGlobal(r.topLeft()), r.size());
        const QRect ed(e->mapToGlobal(QPoint(0, 0)), e->size());
        QWidget *f = QApplication::focusWidget();
        const bool focused = f && (f == e || e->isAncestorOf(f));
        const bool yes = e->isVisible() && std::abs(ed.left() - cell.left()) < 3 && std::abs(ed.top() - cell.top()) < 4
                      && std::abs(ed.width() - cell.width()) < 4 && ed.height() < 40 && focused;
        *got = yes ? "True" : QString("False (editor %1,%2 %3x%4, cell %5,%6 %7x%8, focus %9)").arg(ed.left()).arg(ed.top()).arg(ed.width()).arg(ed.height())
                                 .arg(cell.left()).arg(cell.top()).arg(cell.width()).arg(cell.height()).arg(focused ? "yes" : "no");
        *ok = (*got).compare(m.captured(4), Qt::CaseInsensitive) == 0;
        return true;
    }
    static const QRegularExpression datalist(R"(^\[\.\.\.document\.querySelector\('\.ood-dlg datalist'\)\.children\]\.map\(o => o\.value\)\.join\(','\) ==> (.*)$)");
    if ((m = datalist.match(rest)).hasMatch()) {          // an editable combo box's items
        QComboBox *cb = qobject_cast<QComboBox *>(inPlace("[list]"));
        QStringList v;
        for (int i = 0; cb && i < cb->count(); ++i) v << cb->itemText(i);
        *got = cb ? v.join(',') : "no editable combo box"; *ok = *got == m.captured(1); return true;
    }
    if ((m = cellText.match(rest)).hasMatch()) {
        QTreeWidget *tw = firstLv();
        QTreeWidgetItem *it = tw ? tw->topLevelItem(m.captured(1).toInt()) : nullptr;
        *got = it ? it->text(m.captured(2).toInt()) : "no row";
        *ok = *got == m.captured(3); return true;
    }
    if ((m = hiddenOne.match(rest)).hasMatch()) {
        QWidget *e = inPlace(m.captured(1));
        *got = !e || !e->isVisible() ? "True" : "False";
        *ok = (*got).compare(m.captured(2), Qt::CaseInsensitive) == 0; return true;
    }
    if ((m = firstOptionJson.match(rest)).hasMatch()) {   // the newest dialog's first list box item, as JSON
        QWidget *root = topDialog();
        auto *lw = root ? root->findChild<QListWidget *>() : nullptr;
        QString t = lw && lw->count() ? lw->item(0)->text() : QString();
        *got = "\"" + t.replace("\\", "\\\\").replace("\"", "\\\"").replace("\t", "\\t") + "\"";
        *ok = *got == m.captured(1); return true;
    }
    if ((m = tabbedUnder.match(rest)).hasMatch()) {       // a tabbed column starts under its heading
        QWidget *root = topDialog();
        auto *lw = root ? root->findChild<QListWidget *>() : nullptr;
        QWidget *head = nullptr;
        for (QWidget *w : root ? root->findChildren<QWidget *>() : QList<QWidget *>()) if (w->isVisible() && plain(widgetText(w)) == m.captured(2)) { head = w; break; }
        if (!lw || !lw->count() || !head) { *got = "no list box, item or heading"; *ok = false; return true; }
        const QString text = lw->item(0)->text();
        const int upTo = text.indexOf(m.captured(1));
        auto *dl = dynamic_cast<TabStopDelegate *>(lw->itemDelegate());
        const QFontMetrics fm(lw->font());
        int x = 0;
        const QStringList parts = text.left(upTo).split('\t');
        for (int k = 0; k < parts.size(); ++k) { x += fm.horizontalAdvance(parts[k]); if (k < parts.size() - 1) x = TabStopDelegate::nextStop(dl ? dl->stops : QList<int>(), x); }
        const int want = head->mapToGlobal(QPoint(0, 0)).x() - lw->mapToGlobal(QPoint(0, 0)).x();
        const bool yes = std::abs(x - want) < m.captured(3).toInt();
        *got = yes ? "True" : QString("False (text at %1, heading at %2)").arg(x).arg(want);
        *ok = (*got).compare(m.captured(4), Qt::CaseInsensitive) == 0; return true;
    }
    if ((m = valueIs.match(rest)).hasMatch()) {
        QObject *o = find(m.captured(1), why);
        const bool same = o && valueOf(o) == m.captured(2);
        *got = o ? (same ? "True" : "False") : "nothing";
        *ok = (*got).compare(m.captured(3), Qt::CaseInsensitive) == 0;
        return true;
    }
    if ((m = firstCell.match(rest)).hasMatch()) {         // the first cell of the first row
        QObject *o = find(m.captured(1) + ".ood-lv", why);
        auto *tw = qobject_cast<QTreeWidget *>(o);
        *got = tw && tw->topLevelItemCount() ? tw->topLevelItem(0)->text(0) : "no row";
        *ok = *got == m.captured(2);
        return true;
    }
    if ((m = value.match(rest)).hasMatch()) {
        const QString sel = m.captured(1), want = m.captured(3);
        if (sel == ".ood-tabbtn.ood-cur") {
            QWidget *root = topDialog();
            for (auto *bar : root ? root->findChildren<QTabBar *>("ood-tabstrip") : QList<QTabBar *>()) if (bar->isVisible()) { *got = plain(bar->tabText(bar->currentIndex())); break; }
        } else {
            QObject *o = find(sel, why);
            if (o) *got = m.captured(2) == "title" ? (qobject_cast<QWidget *>(o) ? qobject_cast<QWidget *>(o)->toolTip() : QString()) : valueOf(o);
        }
        *ok = *got == want;
        return true;
    }
    if ((m = includes.match(rest)).hasMatch()) {
        QWidget *root = topDialog();
        const bool has = root && dialogText(root).contains(m.captured(2));
        *got = has ? "True" : "False";
        *ok = (*got).compare(m.captured(3), Qt::CaseInsensitive) == 0;
        return true;
    }
    if ((m = rows.match(rest)).hasMatch()) {
        QObject *o = find(m.captured(1), why);
        auto *tw = qobject_cast<QTreeWidget *>(o);
        *got = tw ? QString::number(tw->topLevelItemCount()) : "no list view";
        *ok = *got == m.captured(2);
        return true;
    }
    static const QRegularExpression children(R"(^\[\.\.\.document\.querySelectorAll\('\.ood-child'\)\]\.filter\(e => e\.style\.visibility !== 'hidden'\)\.length ==> (\d+)$)");
    static const QRegularExpression weight(R"(^getComputedStyle\(document\.querySelector\('([^']+)'\)\)\.fontWeight ==> (\d+)$)");
    static const QRegularExpression dialogsShown(R"(^document\.querySelectorAll\('\.ood-dlg'\)\.length ==> (\d+)$)");
    if ((m = children.match(rest)).hasMatch()) {
        QWidget *root = topDialog();
        int n = 0;
        for (QWidget *ch : root ? root->findChildren<QWidget *>("ood-child") : QList<QWidget *>()) n += ch->isVisible() ? 1 : 0;
        *got = QString::number(n);
        *ok = *got == m.captured(1);
        return true;
    }
    if ((m = weight.match(rest)).hasMatch()) {
        QObject *o = find(m.captured(1), why);
        auto *w = qobject_cast<QWidget *>(o);
        *got = w ? QString::number(w->font().bold() ? 700 : 400) : "nothing";
        *ok = *got == m.captured(2);
        return true;
    }
    if ((m = dialogsShown.match(rest)).hasMatch()) {      // the page's dialogs: the windows, each child is .ood-child
        int n = 0;
        for (auto &kv : dialogs) n += kv.second->win->isVisible() && kv.second->win->isWindow() ? 1 : 0;
        *got = QString::number(n);
        *ok = *got == m.captured(1);
        return true;
    }
    if ((m = shown.match(rest)).hasMatch()) {
        QWidget *root = topDialog();
        QStringList v;
        for (auto *t : root ? root->findChildren<QPlainTextEdit *>() : QList<QPlainTextEdit *>()) v << (t->isVisible() ? "true" : "false");
        *got = v.join(',');
        *ok = *got == m.captured(2);
        return true;
    }
    return false;
}

/* The player's layout mark (marklayout): the client area's size and each control's rectangle, in the order
 * the page has them as .ood-c children of the client; the steps' month calendar pick (mcpick). */
struct LayoutMark { Dlg *d = nullptr; QSize client; std::vector<QRect> rects, pages; std::vector<std::vector<QRect>> pageCtls; } layoutMark;
QDate pickedDay;

Dlg *dialogOf(QWidget *w) { for (auto &kv : dialogs) if (w && kv.second->win == w->window()) return kv.second; return nullptr; }
std::vector<QRect> layoutNow(Dlg *d) {
    std::vector<QRect> out;
    for (int id : d->order) { auto &c = d->ctrls[id]; if (c.el && c.el->parentWidget() == d->client) out.push_back(c.el->geometry()); }
    return out;
}
std::vector<Dlg *> pagesOf(Dlg *d) {                       // the dialogs embedded in d's client area (ControlDialogs), as created
    std::vector<Dlg *> out;
    for (auto &kv : dialogs) if (kv.second != d && kv.second->win && d->client->isAncestorOf(kv.second->win)) out.push_back(kv.second);
    return out;
}
std::vector<QRect> pagesNow(Dlg *d) {                      // each embedded dialog's client area, in d's client area
    std::vector<QRect> out;
    for (Dlg *p : pagesOf(d)) out.push_back(QRect(p->client->mapTo(d->client, QPoint(0, 0)), p->client->size()));
    return out;
}
std::vector<std::vector<QRect>> pageCtlsNow(Dlg *d) {
    std::vector<std::vector<QRect>> out;
    for (Dlg *p : pagesOf(d)) out.push_back(layoutNow(p));
    return out;
}
Mc *mcOf(QObject *o) {
    for (auto &kv : dialogs) for (auto &c : kv.second->ctrls) if (c.second.mc && (QObject *)c.second.el == o) return c.second.mc.get();
    return nullptr;
}
/* One field of a Qt dialect expectation: N, *, >N, <N, =W or =H (the marked client size), or dxK dyK dwK dhK
 * (that change of the Kth control). */
bool fieldOk(const QString &want, double got, const std::vector<QRect> &now) {
    if (want == "*") return true;
    if (want.startsWith('>')) return got > want.mid(1).toDouble();
    if (want.startsWith('<')) return got < want.mid(1).toDouble();
    if (want == "=W") return got == layoutMark.client.width();
    if (want == "=H") return got == layoutMark.client.height();
    static const QRegularExpression ref(R"(^d([xywh])(\d+)$)");
    if (auto m = ref.match(want); m.hasMatch()) {
        const size_t k = m.captured(2).toUInt();
        if (k >= now.size() || k >= layoutMark.rects.size()) return false;
        const QRect a = layoutMark.rects[k], b = now[k];
        const QString f = m.captured(1);
        return got == (f == "x" ? b.x() - a.x() : f == "y" ? b.y() - a.y() : f == "w" ? b.width() - a.width() : b.height() - a.height());
    }
    return got == want.toDouble();
}
bool qtExpect(const QString &rest, bool *ok, QString *got, QString *why) {
    const QString what = rest.section(' ', 0, 0), arg = rest.section(' ', 1).section(" ==> ", 0, 0).trimmed(), want = rest.section(" ==> ", 1);
    static const QStringList words = {"delta", "right", "scaled", "unchanged", "limits", "mcTitle", "mcBold", "mcBoldIn", "mcFits", "mcSel", "mcSelShown",
                                      "tipShown", "tipText", "tipTitle", "tipLines", "tipWidthSet", "tipBesideItem", "tipAtClient",
                                      "pages", "pagesSame", "pageDelta", "pageInTab", "pageCtlDelta",
                                      "inTab", "width", "lvColumn", "lvHeaders", "tabsWide", "tabCurrent", "disabled"};
    if (!words.contains(what)) return false;
    {                                                     // controls of the top dialog (v0.10.0: oodListViews)
        Dlg *d = dialogOf(topDialog());
        auto first = [&](bool lv) -> Ctl * {               // in the dialog, then in its embedded dialogs
            if (!d) return nullptr;
            std::vector<Dlg *> all{d}; for (Dlg *p : pagesOf(d)) all.push_back(p);
            for (Dlg *x : all) for (int id : x->order) { Ctl &c = x->ctrls[id]; if (lv ? (bool)c.lv : (bool)c.tab) return &c; }
            return nullptr;
        };
        auto firstLv = [&] { return first(true); };
        auto firstTab = [&] { return first(false); };
        auto truth = [&](bool v, const QString &detail = QString()) { *got = v ? "True" : "False" + detail; *ok = (v ? QString("True") : QString("False")).compare(want, Qt::CaseInsensitive) == 0; return true; };
        if (what == "inTab" || what == "width") {         // SELECTOR inside the tab control, below its strip; its width
            auto *w = qobject_cast<QWidget *>(find(arg, why));
            if (!w || !d) { *got = "no " + arg; *ok = false; return true; }
            const QRect r(w->mapTo(d->client, QPoint(0, 0)), w->size());
            if (what == "width") { *got = QString::number(r.width()); *ok = fieldOk(want, r.width(), {}); return true; }
            Ctl *t = firstTab();
            if (!t) { *got = "no tab control"; *ok = false; return true; }
            const QRect tr = t->el->geometry();
            const int below = tr.top() + t->tab->bar->sizeHint().height();
            return truth(r.top() >= below && r.left() >= tr.left() && r.right() <= tr.right() && r.bottom() <= tr.bottom(), QString(" (%1,%2 %3x%4 in tab %5,%6 %7x%8)").arg(r.x()).arg(r.y()).arg(r.width()).arg(r.height()).arg(tr.x()).arg(tr.y()).arg(tr.width()).arg(tr.height()));
        }
        if (what == "lvColumn" || what == "lvHeaders") {  // a column of the first list-view's rows; its header labels (none outside report view)
            Ctl *c = firstLv();
            if (!c) { *got = "no list-view"; *ok = false; return true; }
            QTreeWidget *tw = c->lv->w;
            QStringList v;
            if (what == "lvColumn") for (int i = 0; i < tw->topLevelItemCount(); ++i) v << tw->topLevelItem(i)->text(arg.toInt());
            else if (!tw->isHeaderHidden()) for (int i = 0; i < tw->columnCount(); ++i) v << tw->headerItem()->text(i);
            *got = v.join('|'); *ok = *got == want; return true;
        }
        if (what == "tabsWide") {                         // every tab of the first tab control at least N wide, and all alike
            Ctl *t = firstTab();
            if (!t) { *got = "no tab control"; *ok = false; return true; }
            QStringList ws; bool yes = t->tab->bar->count() > 0;
            for (int i = 0; i < t->tab->bar->count(); ++i) { const int w = t->tab->bar->tabRect(i).width(); ws << QString::number(w); if (w < arg.toInt() || w != t->tab->bar->tabRect(0).width()) yes = false; }
            return truth(yes, " (" + ws.join(' ') + ")");
        }
        if (what == "tabCurrent") {
            Ctl *t = firstTab();
            *got = t && t->tab->cur >= 0 ? plain(t->tab->tabs[t->tab->cur]) : QString();
            *ok = *got == want; return true;
        }
        if (what == "disabled") {                         // the button with that text
            QWidget *root = topDialog();
            for (auto *b : root ? root->findChildren<QAbstractButton *>() : QList<QAbstractButton *>())
                if (plain(b->text()).trimmed() == arg && b->isVisible()) return truth(!b->isEnabled());
            *got = "no button " + arg; *ok = false; return true;
        }
    }
    if (what.startsWith("page")) {                        // the dialogs embedded in the marked dialog (pagedTab, v0.19.0)
        Dlg *d = layoutMark.d;
        if (!d || !dialogs.count(d->key)) { *got = "no marklayout"; *ok = false; return true; }
        const std::vector<QRect> pages = pagesNow(d);
        const QStringList fields = want.split(' ', Qt::SkipEmptyParts), args = arg.split(' ', Qt::SkipEmptyParts);
        auto deltas = [&](const QRect &a, const QRect &b) {
            const double v[4] = {(double)b.x() - a.x(), (double)b.y() - a.y(), (double)b.width() - a.width(), (double)b.height() - a.height()};
            *got = QString("%1 %2 %3 %4").arg(v[0]).arg(v[1]).arg(v[2]).arg(v[3]);
            *ok = fields.size() == 4;
            for (int i = 0; i < 4 && *ok; ++i) *ok = fieldOk(fields[i], v[i], layoutNow(d));
            return true;
        };
        if (what == "pages") { *got = QString::number(pages.size()); *ok = *got == want; return true; }
        if (what == "pagesSame") {
            bool same = !pages.empty();
            for (const QRect &r : pages) if (r != pages[0]) same = false;
            *got = same ? "True" : "False"; *ok = (*got).compare(want, Qt::CaseInsensitive) == 0; return true;
        }
        const size_t k = args.value(0).toUInt();
        if (k >= pages.size() || k >= layoutMark.pages.size()) { *got = "no page " + args.value(0); *ok = false; return true; }
        if (what == "pageDelta") return deltas(layoutMark.pages[k], pages[k]);
        if (what == "pageCtlDelta") {
            const std::vector<std::vector<QRect>> now = pageCtlsNow(d);
            const size_t n = args.value(1).toUInt();
            if (k >= now.size() || n >= now[k].size() || n >= layoutMark.pageCtls[k].size()) { *got = "no control " + args.value(1) + " on page " + args.value(0); *ok = false; return true; }
            return deltas(layoutMark.pageCtls[k][n], now[k][n]);
        }
        if (what == "pageInTab") {                        // inside the tab control (the Nth control), below its strip
            const std::vector<QRect> ctls = layoutNow(d);
            const size_t t = args.value(1).toUInt();
            Ctl *tc = nullptr;
            size_t i = 0;
            for (int id : d->order) { auto &c = d->ctrls[id]; if (c.el && c.el->parentWidget() == d->client) { if (i == t) tc = &c; ++i; } }
            if (!tc || !tc->tab) { *got = "control " + args.value(1) + " is no tab"; *ok = false; return true; }
            const QRect tr = tc->el->geometry(), p = pages[k];
            const int strip = tc->tab->bar->sizeHint().height();
            const bool in = p.left() > tr.left() && p.top() >= tr.top() + strip && p.right() < tr.right() && p.bottom() < tr.bottom();
            *got = in ? "True" : QString("False (page %1,%2 %3x%4, tab %5,%6 %7x%8, strip %9)").arg(p.x()).arg(p.y()).arg(p.width()).arg(p.height()).arg(tr.x()).arg(tr.y()).arg(tr.width()).arg(tr.height()).arg(strip);
            *ok = in == (want.compare("True", Qt::CaseInsensitive) == 0); return true;
        }
    }
    if (what.startsWith("tip")) {                         // the tool tip box (v0.18.0): .ood-tip in the page
        const bool shown = tipBox.el && tipBox.el->isVisible();
        auto truth = [&](bool v, const QString &detail = QString()) { *got = v ? "True" : "False" + detail; *ok = (v ? QString("True") : QString("False")).compare(want, Qt::CaseInsensitive) == 0; return true; };
        if (what == "tipShown") return truth(shown);
        if (!shown) { *got = "no tip shown"; *ok = false; return true; }
        if (what == "tipText") { *got = tipBox.body->text().split('\n').join('/'); *ok = *got == want; return true; }
        if (what == "tipTitle") { *got = tipBox.title->isVisible() ? tipBox.title->text() : QString(); *ok = *got == want; return true; }
        if (what == "tipLines") { *got = QString::number(tipBox.body->text().split('\n').size()); *ok = *got == want; return true; }
        if (what == "tipWidthSet") return truth(tipBox.body->maximumWidth() < QWIDGETSIZE_MAX);
        const QPoint t = tipBox.el->pos();
        if (what == "tipAtClient") {                      // the tip's top left on the client area's, within 1 pixel
            Dlg *d = tipBox.d;
            if (!d || !dialogs.count(d->key)) { *got = "no dialog"; *ok = false; return true; }
            const QPoint c = d->client->mapToGlobal(QPoint(0, 0));
            return truth(std::abs(t.x() - c.x()) <= 1 && std::abs(t.y() - c.y()) <= 1, QString(" (tip %1,%2, client %3,%4)").arg(t.x()).arg(t.y()).arg(c.x()).arg(c.y()));
        }
        if (what == "tipBesideItem") {                    // left 5 pixels right of the item's row, top on its top, within 2
            QObject *o = find(".ood-dlg >> text=" + arg, why);
            auto *tw = qobject_cast<QTreeWidget *>(o);
            if (!tw || !pendingItem) { *got = "no item " + arg; *ok = false; return true; }
            QRect r = tw->visualItemRect(pendingItem); r.setLeft(0); r.setWidth(tw->viewport()->width());
            const QPoint tl = tw->viewport()->mapToGlobal(r.topLeft());
            const int right = tl.x() + r.width();
            return truth(std::abs(t.x() - (right + 5)) <= 2 && std::abs(t.y() - tl.y()) <= 2, QString(" (tip %1,%2, row right %3 top %4)").arg(t.x()).arg(t.y()).arg(right).arg(tl.y()));
        }
    }
    if (what.startsWith("mc")) {                          // the month calendar SELECTOR
        QObject *o = find(arg, why);
        Mc *m = mcOf(o);
        if (!m) { *got = "no month calendar"; *ok = false; return true; }
        const QDate f = mcFirstShown(*m);
        if (what == "mcTitle") {
            *got = QString(MONTHS[m->cal->monthShown() - 1]) + " " + QString::number(m->cal->yearShown());
            QString w = want;
            if (want == "@next") { const QDate n = pickedDay.addMonths(1); w = QString(MONTHS[n.month() - 1]) + " " + QString::number(n.year()); }
            *ok = *got == w; return true;
        }
        if (what == "mcBold" || what == "mcBoldIn") {
            QStringList v;
            for (int k = 0; k < 42; ++k) {
                const QDate d = f.addDays(k);
                if (what == "mcBoldIn" && d.month() != m->cal->monthShown()) continue;
                if (m->cal->dateTextFormat(d).fontWeight() == QFont::Bold) v << d.toString("yyyy-MM-dd");
            }
            *got = v.join(','); *ok = *got == want; return true;
        }
        if (what == "mcFits") {
            QWidget *box = m->cal->parentWidget();
            const bool yes = box->sizeHint().width() <= box->width() + 1;
            *got = yes ? "True" : QString("False (needs %1, has %2)").arg(box->sizeHint().width()).arg(box->width());
            *ok = (*got).compare(want, Qt::CaseInsensitive) == 0; return true;
        }
        if (what == "mcSel") { *got = m->sel.toString("yyyy-MM-dd"); *ok = want == "@picked" ? m->sel == pickedDay : *got == want; return true; }
        if (what == "mcSelShown") {                       // some other control of the dialog shows the selected day as Month D, YYYY
            const QString text = QString(MONTHS[m->sel.month() - 1]) + " " + QString::number(m->sel.day()) + ", " + QString::number(m->sel.year());
            QWidget *root = m->cal->window();
            bool yes = false;
            for (QWidget *w : root->findChildren<QWidget *>()) if (w->isVisible() && !m->cal->parentWidget()->isAncestorOf(w) && plain(widgetText(w)).trimmed() == text) yes = true;
            *got = yes ? "True" : "False (" + text + " not shown)";
            *ok = (*got).compare(want, Qt::CaseInsensitive) == 0; return true;
        }
    }
    Dlg *d = layoutMark.d;
    if (!d || !dialogs.count(d->key)) { *got = "no marklayout"; *ok = false; return true; }
    const std::vector<QRect> now = layoutNow(d);
    if (now.size() != layoutMark.rects.size()) { *got = "the number of controls changed"; *ok = false; return true; }
    const QStringList fields = want.split(' ', Qt::SkipEmptyParts);
    if (what == "delta" || what == "right") {
        const size_t k = arg.toUInt();
        if (k >= now.size()) { *got = "no control " + arg; *ok = false; return true; }
        const QRect a = layoutMark.rects[k], b = now[k];
        if (what == "right") {
            const int r = (b.x() + b.width()) - (a.x() + a.width());
            *got = QString::number(r); *ok = fieldOk(want, r, now); return true;
        }
        const double v[4] = {(double)b.x() - a.x(), (double)b.y() - a.y(), (double)b.width() - a.width(), (double)b.height() - a.height()};
        *got = QString("%1 %2 %3 %4").arg(v[0]).arg(v[1]).arg(v[2]).arg(v[3]);
        *ok = fields.size() == 4;
        for (int i = 0; i < 4 && *ok; ++i) *ok = fieldOk(fields[i], v[i], now);
        return true;
    }
    if (what == "scaled") {                               // every control is the marked one times F, within 2 pixels
        const double f = arg.toDouble();
        bool yes = true; QString bad;
        for (size_t k = 0; k < now.size(); ++k) {
            const QRect a = layoutMark.rects[k], b = now[k];
            const int av[4] = {a.x(), a.y(), a.width(), a.height()}, bv[4] = {b.x(), b.y(), b.width(), b.height()};
            for (int i = 0; i < 4; ++i) if (std::abs(bv[i] - f * av[i]) > 2) { yes = false; if (bad.isEmpty()) bad = QString(" (control %1: %2 %3 %4 %5 was %6 %7 %8 %9)").arg(k).arg(bv[0]).arg(bv[1]).arg(bv[2]).arg(bv[3]).arg(av[0]).arg(av[1]).arg(av[2]).arg(av[3]); }
        }
        *got = yes ? "True" : "False" + bad; *ok = (*got).compare(want, Qt::CaseInsensitive) == 0; return true;
    }
    if (what == "unchanged") {                            // the client area and every control as marked
        const bool yes = d->client->size() == layoutMark.client && now == layoutMark.rects;
        *got = yes ? "True" : QString("False (client %1x%2, marked %3x%4)").arg(d->client->width()).arg(d->client->height()).arg(layoutMark.client.width()).arg(layoutMark.client.height());
        *ok = (*got).compare(want, Qt::CaseInsensitive) == 0; return true;
    }
    if (what == "limits") {                               // the client area's minimum width, height, maximum width, height
        const QSize lo = d->client->minimumSize(), hi = d->client->maximumSize();
        const double v[4] = {(double)lo.width(), (double)lo.height(), (double)hi.width(), (double)hi.height()};
        *got = QString("%1 %2 %3 %4").arg(v[0]).arg(v[1]).arg(v[2]).arg(v[3]);
        *ok = fields.size() == 4;
        for (int i = 0; i < 4 && *ok; ++i) *ok = fieldOk(fields[i], v[i], now);
        return true;
    }
    return false;
}

void stepFailed(const QString &line, const QString &why) {
    fflush(stdout);
    fprintf(stderr, "oodqt: STEP FAILED: %s (%s)\n", qPrintable(line), qPrintable(why));
    fflush(stderr);
    std::_Exit(3);
}

void stepTick() {
    if (!steps || steps->at >= steps->lines.size()) { if (steps) steps->timer.stop(); return; }
    if (steps->sleepUntil >= 0) {
        if (steps->since.elapsed() < steps->sleepUntil) return;
        steps->sleepUntil = -1; steps->at++; steps->since.restart(); return;
    }
    const QString line = steps->lines[steps->at].trimmed();
    if (line.isEmpty() || line.startsWith('#')) { steps->at++; return; }
    const QString verb = line.section(' ', 0, 0), rest = line.section(' ', 1);
    QString why;
    auto done = [&] { fprintf(stderr, "oodqt: step %d ok: %s\n", steps->at + 1, qPrintable(line)); steps->at++; steps->since.restart(); };
    if (verb == "sleep") { steps->sleepUntil = rest.toInt(); steps->since.restart(); return; }
    if (verb == "shot") {
        if (QWidget *w = topDialog()) if (!steps->shots.isEmpty()) {
            // the window, with the tool tip box painted where it stands (it is a window of its own, as on Windows)
            const QPoint origin = w->mapToGlobal(QPoint(0, 0));
            QRect area(origin, w->size());
            const bool tip = tipBox.el && tipBox.el->isVisible();
            if (tip) area = area.united(tipBox.el->geometry());
            QPixmap shot(area.size());
            shot.fill(QColor(240, 240, 240));
            QPainter p(&shot);
            p.drawPixmap(origin - area.topLeft(), w->grab());
            if (tip) p.drawPixmap(tipBox.el->pos() - area.topLeft(), tipBox.el->grab());
            p.end();
            shot.save(steps->shots + "/" + rest.trimmed() + ".png");
        }
        done(); return;
    }
    if (verb == "expect") {
        bool ok = false; QString got;
        if (qtExpect(rest, &ok, &got, &why) || translatedExpect(rest, &ok, &got, &why)) {
            if (ok) { done(); return; }
            if (steps->since.elapsed() > 5000) stepFailed(line, "got " + got);
            return;
        }
    }
    if (verb == "eval" || (verb == "expect" && !rest.startsWith("text ") && !rest.startsWith("value ") && !rest.startsWith("size ") && !rest.startsWith("moved ")))
        stepFailed(line, "a JavaScript step: give this test a Qt steps file, NAME.qt.steps in oodialog-qt6/tests/steps");
    if (verb == "expect") {                               // expect text|value|size SELECTOR ==> VALUE  (the Qt dialect; size is "W H" in pixels)
        const QString what = rest.section(' ', 0, 0), sel = rest.section(' ', 1).section(" ==> ", 0, 0), want = rest.section(" ==> ", 1);
        QObject *o = find(sel, &why);
        auto *ow = qobject_cast<QWidget *>(o);
        if (what == "moved") {                            // expect moved SELECTOR ==> True: changed since mark
            const QString now = o ? pictureState(o) : QString();
            const QString moved = o && now != markedState ? "True" : "False";
            if (moved.compare(want, Qt::CaseInsensitive) == 0) { done(); return; }
            if (steps->since.elapsed() > 5000) stepFailed(line, "got " + moved + " (" + now + ")");
            return;
        }
        const QString got = what == "size" ? (ow ? QString::number(ow->width()) + " " + QString::number(ow->height()) : QString()) : o ? valueOf(o) : QString();
        if (o && got == want) { done(); return; }
        if (steps->since.elapsed() > 5000) stepFailed(line, o ? "got " + got : why);
        return;
    }
    if (verb == "wait" || verb == "click" || verb == "fill" || verb == "select") {
        QString sel = rest, value;
        if (verb == "fill" || verb == "select") { sel = rest.section(" => ", 0, 0); value = rest.section(" => ", 1); }
        QObject *o = find(sel, &why);
        if (!o) { if (steps->since.elapsed() > 10000) stepFailed(line, why); return; }
        if (verb == "click") {
            if (auto *a = qobject_cast<QAction *>(o)) {
                if (a->menu()) {
                    auto *bar = topDialog()->findChild<QMenuBar *>("ood-menubar");
                    a->menu()->popup(bar ? bar->mapToGlobal(bar->actionGeometry(a).bottomLeft()) : QPoint(0, 0));
                } else if (a->isEnabled()) {          // a grayed item does nothing and the menu stays open, as on Windows
                    a->trigger();
                    for (QWidget *w : QApplication::topLevelWidgets()) if (auto *m = qobject_cast<QMenu *>(w)) m->hide();
                }
            }
            else if (auto *tw = qobject_cast<QTreeWidget *>(o); tw && pendingCol >= 0) emit tw->header()->sectionClicked(pendingCol);
            else if (auto *tw = qobject_cast<QTreeWidget *>(o); tw && pendingItem) {
                if (tw->objectName() == "ood-lv") {
                    syntheticMouse = true;
                    if (!pendingCheck) tw->setCurrentItem(pendingItem);   // a current row first: focus would make row 0 current; a check box click selects nothing
                    tw->setFocus();
                    if (pendingCheck) pendingItem->setCheckState(0, pendingItem->checkState(0) == Qt::Checked ? Qt::Unchecked : Qt::Checked);
                    emit tw->itemClicked(pendingItem, 0); syntheticMouse = false;
                }
                else { syntheticMouse = true; tw->setCurrentItem(pendingItem); syntheticMouse = false; }
            }
            else if (auto *bar = qobject_cast<QTabBar *>(o); bar && pendingTab >= 0) bar->setCurrentIndex(pendingTab);
            else if (auto *b = qobject_cast<QAbstractButton *>(o)) b->click();
            else if (auto *w = qobject_cast<QWidget *>(o)) { w->setFocus(); QMouseEvent p(QEvent::MouseButtonRelease, QPointF(2, 2), QPointF(2, 2), Qt::LeftButton, Qt::NoButton, Qt::NoModifier); QApplication::sendEvent(w, &p); }
        }
        if (verb == "fill") {
            if (auto *e = qobject_cast<QLineEdit *>(o)) { e->setFocus(); e->selectAll(); e->insert(value); }
            else if (auto *t = qobject_cast<QPlainTextEdit *>(o)) { t->setFocus(); t->setPlainText(value); }
            else if (auto *e = qobject_cast<QDateTimeEdit *>(o)) {
                e->setFocus();
                const QDateTime t = QDateTime::fromString(value, e->displayFormat().startsWith("HH") ? "HH:mm:ss" : "yyyy-MM-dd");
                if (e->displayFormat().startsWith("HH")) e->setTime(t.time()); else e->setDate(QDate::fromString(value, "yyyy-MM-dd"));
            }
            for (auto &kv : dialogs) for (auto &cc : kv.second->ctrls) if (cc.second.main == o) cc.second.modified = true;
        }
        if (verb == "select") {
            if (auto *c = qobject_cast<QComboBox *>(o)) {   // by its text, or #N by its index (the Qt dialect)
                const int i = value.startsWith('#') ? value.mid(1).toInt() : c->findText(value);
                c->setCurrentIndex(i); emit c->activated(i);
            }
            if (auto *l = qobject_cast<QListWidget *>(o)) { auto f = l->findItems(value, Qt::MatchExactly); if (!f.isEmpty()) l->setCurrentItem(f[0]); }
        }
        done(); return;
    }
    if (verb == "resize") {                               // resize SELECTOR => W H: the dialog's client area to W x H pixels
        QObject *o = find(rest.section(" => ", 0, 0), &why);
        auto *w = qobject_cast<QWidget *>(o);
        Dlg *hit = nullptr;
        for (auto &kv : dialogs) if (w && kv.second->win == w->window()) hit = kv.second;
        if (!hit) { if (steps->since.elapsed() > 10000) stepFailed(line, why.isEmpty() ? "no dialog" : why); return; }
        const QStringList wh = rest.section(" => ", 1).split(' ', Qt::SkipEmptyParts);
        auto size = [&](const QString &v, int marked) {   // N pixels; +N or -N from the marked layout; xF times it
            if ((v.startsWith('+') || v.startsWith('-')) && layoutMark.d == hit) return marked + v.toInt();
            if (v.startsWith('x') && layoutMark.d == hit) return qRound(marked * v.mid(1).toDouble());
            return v.toInt();
        };
        const int cw = size(wh.value(0), layoutMark.client.width()), ch = size(wh.value(1), layoutMark.client.height());
        hit->win->resize(hit->win->width() + cw - hit->client->width(), hit->win->height() + ch - hit->client->height());
        done(); return;
    }
    if (verb == "drag") {                                 // drag SELECTOR => N: a track bar's thumb to N, then let go
        auto *s = qobject_cast<QSlider *>(find(rest.section(" => ", 0, 0), &why));
        if (!s) { if (steps->since.elapsed() > 10000) stepFailed(line, why.isEmpty() ? "not a track bar" : why); return; }
        const int to = rest.section(" => ", 1).toInt();
        s->setSliderDown(true);
        s->setSliderPosition(to);                         // sliderMoved: DRAG
        s->setSliderDown(false);                          // sliderReleased: ENDTRACK
        done(); return;
    }
    if (verb == "type") {                                 // type TEXT: into whatever has the focus, a key at a time
        QWidget *f = QApplication::focusWidget();
        if (!f) { if (steps->since.elapsed() > 5000) stepFailed(line, "nothing has the focus"); return; }
        for (const QChar ch : rest) {
            QKeyEvent down(QEvent::KeyPress, 0, Qt::NoModifier, QString(ch));
            QKeyEvent up(QEvent::KeyRelease, 0, Qt::NoModifier, QString(ch));
            QApplication::sendEvent(f, &down);
            QApplication::sendEvent(f, &up);
        }
        done(); return;
    }
    if (verb == "mouse") {                                // mouse move|down|up|wheel SELECTOR @ dx dy [delta]: as Playwright's mouse
        const QString what = rest.section(' ', 0, 0), where = rest.section(' ', 1);
        const QString sel = where.section(" @ ", 0, -2);
        const QStringList nums = where.section(" @ ", -1).split(' ', Qt::SkipEmptyParts);
        auto *target = qobject_cast<QWidget *>(find(sel, &why));
        if (!target) { if (steps->since.elapsed() > 10000) stepFailed(line, why); return; }
        QPoint origin(0, 0);                              // a row or a cell: its top left, as the page's element
        if (sel.endsWith(".ood-title")) origin = QPoint(0, -30);   // the title bar: the window manager's, above the window
        if (auto *tw = qobject_cast<QTreeWidget *>(target); tw && pendingItem) {
            QRect r = tw->visualItemRect(pendingItem);
            if (pendingCell >= 0) r.setLeft(tw->columnViewportPosition(pendingCell));
            origin = tw->viewport()->mapTo(tw, r.topLeft());
        }
        const QPoint to = target->mapToGlobal(origin + QPoint(nums.value(0).toDouble(), nums.value(1).toDouble()));
        static QPoint at;                                 // where the player's pointer is
        static quint64 stamp = 1000;
        auto send = [&](QEvent::Type type, QPoint g, Qt::MouseButton b) {
            QWidget *top = target->window();
            QWidget *under = QApplication::widgetAt(g);
            if (!under || under->window() != top) under = target->childAt(target->mapFromGlobal(g));
            if (!under) under = target;
            QCursor::setPos(g);
            QMouseEvent ev(type, QPointF(under->mapFromGlobal(g)), QPointF(g), b, playerButtons, Qt::NoModifier);
            ev.setTimestamp(++stamp);
            QApplication::sendEvent(under, &ev);
        };
        if (what == "move" || what == "up") {             // six steps from where the pointer was, as steps=6
            const QPoint from = at.isNull() ? to : at;
            for (int k = 1; k <= 6; ++k) send(QEvent::MouseMove, from + (to - from) * k / 6, Qt::NoButton);
        } else send(QEvent::MouseMove, to, Qt::NoButton);
        static QElapsedTimer lastDown; static QPoint lastDownAt;
        if (what == "down") {                             // a second press soon on the same spot is a double click, as Qt's window makes it
            playerButtons |= Qt::LeftButton;
            const bool twice = lastDown.isValid() && lastDown.elapsed() < QApplication::doubleClickInterval() && (to - lastDownAt).manhattanLength() < 4;
            send(QEvent::MouseButtonPress, to, Qt::LeftButton);
            if (twice) send(QEvent::MouseButtonDblClick, to, Qt::LeftButton);   // Qt 6: the press, then the double click
            if (qEnvironmentVariableIsSet("OODQT_DEBUG")) fprintf(stderr, "oodqt: mouse down%s at %d,%d over %s\n", twice ? " (double)" : "", to.x(), to.y(), qPrintable(QApplication::widgetAt(to) ? QApplication::widgetAt(to)->metaObject()->className() : QString("nothing")));
            if (twice) lastDown.invalidate(); else { lastDown.start(); lastDownAt = to; }
        }
        if (what == "up") { playerButtons &= ~Qt::LeftButton; send(QEvent::MouseButtonRelease, to, Qt::LeftButton); }
        if (what == "wheel") {                            // Playwright's deltaY: down is positive; Qt's angle: up is positive
            QWidget *under = target->childAt(target->mapFromGlobal(to));
            if (!under) under = target;
            const double dy = nums.value(2).toDouble();
            QWheelEvent ev(QPointF(under->mapFromGlobal(to)), QPointF(to), QPoint(0, -qRound(dy)), QPoint(0, dy > 0 ? -120 : 120), playerButtons, Qt::NoModifier, Qt::NoScrollPhase, false);
            ev.setTimestamp(++stamp);
            QApplication::sendEvent(under, &ev);
        }
        at = to;
        done(); return;
    }
    if (verb == "output") { done(); return; }             // output lines|count TEXT ==> WANT: checked by the runner on the program's output, after it ends
    if (verb == "marklayout") {                           // marklayout SELECTOR: its dialog's client size and controls, for delta, scaled, unchanged, limits
        Dlg *hit = dialogOf(qobject_cast<QWidget *>(find(rest, &why)));
        if (!hit) { if (steps->since.elapsed() > 10000) stepFailed(line, why.isEmpty() ? "no dialog" : why); return; }
        layoutMark = {hit, hit->client->size(), layoutNow(hit), pagesNow(hit), pageCtlsNow(hit)};
        fprintf(stderr, "oodqt: layout marked: client %dx%d, %d controls\n", layoutMark.client.width(), layoutMark.client.height(), (int)layoutMark.rects.size());
        done(); return;
    }
    if (verb == "mcpick") {                               // mcpick SELECTOR => D: click day D of the month shown, with the mouse
        QObject *o = find(rest.section(" => ", 0, 0), &why);
        Mc *m = mcOf(o);
        if (!m) { if (steps->since.elapsed() > 10000) stepFailed(line, why.isEmpty() ? "no month calendar" : why); return; }
        auto *view = m->cal->findChild<QTableView *>("qt_calendar_calendarview");
        const QDate day(m->cal->yearShown(), m->cal->monthShown(), rest.section(" => ", 1).toInt());
        const int k = mcFirstShown(*m).daysTo(day);
        const int col = k % 7 + (m->cal->verticalHeaderFormat() == QCalendarWidget::NoVerticalHeader ? 0 : 1), row = k / 7 + 1;
        const QRect r = view ? view->visualRect(view->model()->index(row, col)) : QRect();
        if (!day.isValid() || r.isEmpty()) stepFailed(line, "no cell for that day");
        pickedDay = day;
        const QPoint at = r.center();
        for (QEvent::Type t : {QEvent::MouseButtonPress, QEvent::MouseButtonRelease}) {
            QMouseEvent ev(t, at, view->viewport()->mapToGlobal(at), Qt::LeftButton, t == QEvent::MouseButtonPress ? Qt::LeftButton : Qt::NoButton, Qt::NoModifier);
            QApplication::sendEvent(view->viewport(), &ev);
        }
        done(); return;
    }
    if (verb == "mark") {                                 // mark SELECTOR: remember its picture and place, for expect moved
        QObject *o = find(rest, &why);
        if (!o) { if (steps->since.elapsed() > 10000) stepFailed(line, why); return; }
        markedState = pictureState(o);
        done(); return;
    }
    if (verb == "dismiss") {                              // the top message box's first button, or the newest of several dialogs' close box
        for (QWidget *w : QApplication::topLevelWidgets()) if (auto *mb = qobject_cast<QMessageBox *>(w); mb && mb->isVisible() && !mb->buttons().isEmpty()) {
            mb->buttons().first()->click(); done(); return;
        }
        Dlg *newest = nullptr; int shown = 0;
        for (auto &kv : dialogs) if (kv.second->win->isVisible() && kv.second->win->isWindow()) { newest = kv.second; ++shown; }
        if (shown > 1 && newest && !newest->noClose) newest->win->close();
        done(); return;
    }
    if (verb == "dblclick") {                             // dblclick SELECTOR => ITEM: a list box item, double-clicked
        QObject *o = find(rest.section(" => ", 0, 0), &why);
        auto *lw = qobject_cast<QListWidget *>(o);
        if (!lw) { if (steps->since.elapsed() > 10000) stepFailed(line, why.isEmpty() ? "not a list box" : why); return; }
        const auto hits = lw->findItems(rest.section(" => ", 1), Qt::MatchExactly);
        if (hits.isEmpty()) { if (steps->since.elapsed() > 10000) stepFailed(line, "no item " + rest.section(" => ", 1)); return; }
        lw->setFocus(); lw->setCurrentItem(hits.first());
        emit lw->itemDoubleClicked(hits.first());
        done(); return;
    }
    if (verb == "focus") {                                // focus SELECTOR: the widget, and its window, take the keys
        QObject *o = find(rest, &why);
        if (!o) { if (steps->since.elapsed() > 10000) stepFailed(line, why); return; }
        if (auto *w = qobject_cast<QWidget *>(o)) { w->window()->activateWindow(); w->setFocus(); }
        done(); return;
    }
    if (verb == "press") {                                // press KEY, Shift+F2, Control+k
        QStringList parts = rest.trimmed().split('+');
        const QString k = parts.takeLast();
        Qt::KeyboardModifiers mods;
        for (const QString &m : parts) {
            if (m == "Shift") mods |= Qt::ShiftModifier;
            else if (m == "Control") mods |= Qt::ControlModifier;
            else if (m == "Alt") mods |= Qt::AltModifier;
        }
        int key = 0;
        if (k == "Enter") key = Qt::Key_Return; else if (k == "Escape") key = Qt::Key_Escape; else if (k == "Tab") key = Qt::Key_Tab;
        else if (k.size() > 1 && k[0] == 'F' && k.mid(1).toInt() >= 1) key = Qt::Key_F1 + k.mid(1).toInt() - 1;
        else if (k.size() == 1) key = k[0].toUpper().unicode();
        QWidget *target = QApplication::focusWidget() ? QApplication::focusWidget() : topDialog();
        for (QWidget *w : QApplication::topLevelWidgets()) if (qobject_cast<QMenu *>(w) && w->isVisible()) target = w;   // an open menu takes the key
        if (!target || !key) stepFailed(line, "no focus or unknown key");
        const QString text = (k.size() == 1 && !(mods & (Qt::ControlModifier | Qt::AltModifier))) ? k : QString();
        QKeyEvent dn(QEvent::KeyPress, key, mods, text);
        QApplication::sendEvent(target, &dn);
        done(); return;
    }
    stepFailed(line, "this step is not supported by the Qt player (" + verb + ")");
}

/* Qt runs on a thread of its own, started by the first call and running its event
 * loop for the life of the process.  Every Rexx thread's calls are run there and
 * oodqt_next only waits on the event queue, so Qt never waits on Rexx: a Rexx
 * thread blocked on a guard cannot stop the renderer, and no thread is "the" GUI thread. */
std::thread qtThread;
std::mutex startLock;
std::condition_variable started;

void setUp() {                                         // on the Qt thread
    static int argc = 1;
    static char name[] = "oodqt";
    static char *argv[] = {name, nullptr};
    app = new QApplication(argc, argv);
    app->setQuitOnLastWindowClosed(false);
    app->installEventFilter(new KeyFilter(app));
    app->installEventFilter(new MouseHub(app));
    const QByteArray file = qgetenv("OODQT_STEPS");
    if (!file.isEmpty()) {
        QFile f(QString::fromLocal8Bit(file));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            steps = new Steps;
            steps->lines = QTextStream(&f).readAll().split('\n');
            const QString home = QString::fromLocal8Bit(qgetenv("OODQT_HOME"));   // the runner's fresh directory is the page's /home/rexx
            if (!home.isEmpty()) for (QString &l : steps->lines) l.replace("/home/rexx", home);
            steps->shots = QString::fromLocal8Bit(qgetenv("OODQT_SHOTS"));
            steps->since.start();
            QObject::connect(&steps->timer, &QTimer::timeout, stepTick);
            steps->timer.start(50);
        }
    }
}

void shutDown() {                                      // stop the loop and let the Qt thread clean up, once
    static std::once_flag once;
    std::call_once(once, [] {
    if (qEnvironmentVariableIsSet("OODQT_DEBUG")) fprintf(stderr, "oodqt: shutdown requested\n");
    if (!app) return;
    QMetaObject::invokeMethod(app, [] { QApplication::quit(); }, Qt::QueuedConnection);
    if (qtThread.joinable()) qtThread.join();
    });
}

void ensureApp() {
    std::unique_lock<std::mutex> g(startLock);
    if (app) return;
    qtThread = std::thread([] {
        {
            std::lock_guard<std::mutex> s(startLock);
            setUp();
        }
        started.notify_all();
        app->exec();
        if (qEnvironmentVariableIsSet("OODQT_DEBUG")) fprintf(stderr, "oodqt: Qt loop ended\n");
        // The process is exiting: widgets are left for it to reclaim.  Deleting them here freed
        // windows already owned by other windows and corrupted the heap (v0.1.1 test runs).
        if (steps) steps->timer.stop();
        // A program that ends before its steps are done has not passed them: the rest were never checked
        // (up to v0.7.0 such a run counted as a pass; dropDownComboBox's Enter closed the dialog early in v0.8.0's first run).
        if (steps) for (int i = steps->at; i < steps->lines.size(); ++i) {
            const QString l = steps->lines[i].trimmed();
            if (l.isEmpty() || l.startsWith('#')) continue;
            fflush(stdout);
            fprintf(stderr, "oodqt: STEPS NOT FINISHED: the program ended at step %d: %s\n", i + 1, qPrintable(l));
            fflush(stderr);
            std::_Exit(4);
        }
        // Qt's pixmap cache is a global with a flush timer: emptied here, on its own thread, it stops the timer.
        // Left to the process's exit handlers, it was destroyed on the main thread ("Timers cannot be stopped
        // from another thread", every run up to v0.3.0).
        QPixmapCache::clear();
    });
    started.wait(g, [] { return app != nullptr; });
    std::atexit(shutDown);
}

QString onQt(const QString &n, const QString &p) {
    if (QThread::currentThread() == app->thread()) return call(n, p);
    QString result;
    QMetaObject::invokeMethod(app, [&] { result = call(n, p); }, Qt::BlockingQueuedConnection);
    return result;
}

}  // namespace

RexxRoutine2(RexxStringObject, oodqt_call, CSTRING, name, RexxStringObject, payload)
{
    ensureApp();
    const QString p = QString::fromUtf8(context->StringData(payload), (int)context->StringLength(payload));
    const QByteArray out = onQt(QString::fromUtf8(name), p).toUtf8();
    return context->NewString(out.constData(), out.size());
}

/* Wait up to ms for one queued event; Qt keeps running on its own thread meanwhile. */
RexxRoutine1(RexxStringObject, oodqt_next, int, ms)
{
    ensureApp();
    QByteArray out;
    {
        std::unique_lock<std::mutex> g(eventsLock);
        eventsReady.wait_for(g, std::chrono::milliseconds(std::max(0, ms)), [] { return !events.empty(); });
        if (events.empty()) return context->NullString();
        out = events.front().toUtf8();
        events.pop_front();
        if (qEnvironmentVariableIsSet("OODQT_DEBUG")) fprintf(stderr, "oodqt: thread %zx takes %s\n", std::hash<std::thread::id>{}(std::this_thread::get_id()) % 0xffff, out.replace('1f', '|').constData());
    }
    return context->NewString(out.constData(), out.size());
}

/* ooRexx calls this before it unloads the library: the Qt thread must be gone by then. */
void RexxEntry oodqt_unload(RexxThreadContext *) { shutDown(); }

RexxRoutineEntry oodqt_routines[] = {
    REXX_TYPED_ROUTINE(oodqt_call, oodqt_call),
    REXX_TYPED_ROUTINE(oodqt_next, oodqt_next),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry oodqt_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "oodqt",
    "0.10.0",
    NULL,
    oodqt_unload,
    oodqt_routines,
    NULL
};

OOREXX_GET_PACKAGE(oodqt);

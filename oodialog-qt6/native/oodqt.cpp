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
#include <QSlider>
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
struct TabC { QStringList tabs; int cur = -1; bool rendering = false; QTabBar *bar = nullptr; QWidget *box = nullptr; };

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
    int lo = 0, hi = 100, pos = 0, page = 20, line = 1, buddy = 0;   // track bar and up-down
    bool buddyInt = false, wrap = false;
    QDateTime when;                                               // date-time picker: the part not shown is kept
};

class OodDialog;

struct Dlg {
    int key = 0;
    QString opts;
    OodDialog *win = nullptr;
    QWidget *client = nullptr;
    QMenuBar *menuBar = nullptr;
    std::map<int, Ctl> ctrls;
    std::vector<int> order;
    std::set<QString> subs;
    std::map<int, QButtonGroup *> radioGroups;
    double fx = 1, fy = 1;
    int defId = 1, group = 0;
    bool shown = false, noClose = false;
};

std::map<int, Dlg *> dialogs;
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
    L.rendering = true;
    QTreeWidget *w = L.w;
    w->clear();
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
        auto *item = new QTreeWidgetItem(w);
        const LvRow &r = L.rows[i];
        const int n = report ? std::max<int>(1, (int)L.cols.size()) : 1;
        for (int k = 0; k < n && k < r.cells.size(); ++k) item->setText(k, r.cells[k]);
        if (checks) item->setCheckState(0, r.chk ? Qt::Checked : Qt::Unchecked);
        item->setSelected(r.sel);
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
    QObject::connect(w, &QTreeWidget::itemClicked, [d, id, L, w](QTreeWidgetItem *item, int col) {
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
    } else if (c.kind == "TRACKBAR") {
        auto *s = new QSlider(has(c.opts, "VERTICAL") ? Qt::Vertical : Qt::Horizontal, parent);
        s->setRange(0, 100); s->setPageStep(20); s->setSingleStep(1);
        if (has(c.opts, "AUTOTICKS")) s->setTickPosition(has(c.opts, "VERTICAL") ? QSlider::TicksRight : QSlider::TicksBelow);
        if (has(c.opts, "VERTICAL")) s->setInvertedAppearance(true);
        QObject::connect(s, &QSlider::sliderMoved, [d, id](int v) { note(d, id, "TRACK", QString::number(v) + FS + "DRAG"); });
        QObject::connect(s, &QSlider::actionTriggered, [d, id, s](int) {
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
        d->client->setFixedSize(w, h);
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
    if (name == "image") return "1";
    if (name == "hasImage") return "0";
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
        if (auto *b = qobject_cast<QAbstractButton *>(c.main)) {
            auto *cb = qobject_cast<QCheckBox *>(b);
            switch (msg) {
            case 0xF5: b->click(); return "0";
            case 0xF0: if (cb && cb->isTristate()) return QString::number(cb->checkState() == Qt::PartiallyChecked ? 2 : cb->isChecked() ? 1 : 0);
                       return b->isChecked() ? "1" : "0";
            case 0xF1: if (cb && cb->isTristate()) cb->setCheckState(w == 2 ? Qt::PartiallyChecked : w == 1 ? Qt::Checked : Qt::Unchecked);
                       else b->setChecked(w == 1);
                       return "0";
            case 0xF2: return QString::number((b->isChecked() ? 1 : 0) | (b->hasFocus() ? 8 : 0));
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
        if (op == "move") { el->move(oa.toInt(), ob.toInt()); return "1"; }
        if (op == "size") { if (c) el->resize(oa.toInt(), ob.toInt()); else d->client->setFixedSize(oa.toInt(), ob.toInt()); return "1"; }
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
            if (cb) { if (at < 0 || at >= cb->count()) { cb->addItem(text); return QString::number(cb->findText(text)); } cb->insertItem(at, text); return QString::number(at); }
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
int pendingTab = -1;                                   // the tab a .ood-tabbtn selector found

QWidget *scopeRoot = nullptr;                          // set while a .ood-child selector searches one child
QObject *find(const QString &selector, QString *why) {
    pendingCheck = false;
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
    if (rest.startsWith("input") && !rest.contains("ood-check")) { for (auto *e : root->findChildren<QLineEdit *>()) if (!qobject_cast<QAbstractSpinBox *>(e->parentWidget())) cands << e; }   // not a picker's own line
    else if (rest.contains(".ood-check")) for (auto *b : root->findChildren<QAbstractButton *>()) { if (qobject_cast<QCheckBox *>(b) || qobject_cast<QRadioButton *>(b)) cands << b; }
    else if (rest.startsWith("textarea")) for (auto *t : root->findChildren<QPlainTextEdit *>()) cands << t;
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
        if (QWidget *w = topDialog()) if (!steps->shots.isEmpty()) w->grab().save(steps->shots + "/" + rest.trimmed() + ".png");
        done(); return;
    }
    if (verb == "expect") {
        bool ok = false; QString got;
        if (translatedExpect(rest, &ok, &got, &why)) {
            if (ok) { done(); return; }
            if (steps->since.elapsed() > 5000) stepFailed(line, "got " + got);
            return;
        }
    }
    if (verb == "eval" || (verb == "expect" && !rest.startsWith("text ") && !rest.startsWith("value ")))
        stepFailed(line, "a JavaScript step: give this test a Qt steps file, NAME.qt.steps in oodialog-qt6/tests/steps");
    if (verb == "expect") {                               // expect text|value SELECTOR ==> VALUE  (the Qt dialect)
        const QString what = rest.section(' ', 0, 0), sel = rest.section(' ', 1).section(" ==> ", 0, 0), want = rest.section(" ==> ", 1);
        QObject *o = find(sel, &why);
        const QString got = o ? valueOf(o) : QString();
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
                    syntheticMouse = true; tw->setCurrentItem(pendingItem); tw->setFocus();   // a current row first: focus would make row 0 current
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
            if (auto *c = qobject_cast<QComboBox *>(o)) { const int i = c->findText(value); c->setCurrentIndex(i); emit c->activated(i); }
            if (auto *l = qobject_cast<QListWidget *>(o)) { auto f = l->findItems(value, Qt::MatchExactly); if (!f.isEmpty()) l->setCurrentItem(f[0]); }
        }
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
    const QByteArray file = qgetenv("OODQT_STEPS");
    if (!file.isEmpty()) {
        QFile f(QString::fromLocal8Bit(file));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            steps = new Steps;
            steps->lines = QTextStream(&f).readAll().split('\n');
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
    "0.3.0",
    NULL,
    oodqt_unload,
    oodqt_routines,
    NULL
};

OOREXX_GET_PACKAGE(oodqt);

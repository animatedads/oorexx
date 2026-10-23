// First native Qt6 resource renderer for ooDialog Linux.
// JSON event stream on stdout, commands as JSON-lines on stdin (Unix QSocketNotifier).
#include <QApplication>
#include <QDialog>
#include <QCloseEvent>
#include <QKeyEvent>
#include <QWidget>
#include <QPushButton>
#include <QAbstractButton>
#include <QCheckBox>
#include <QRadioButton>
#include <QLabel>
#include <QLineEdit>
#include <QTextEdit>
#include <QListWidget>
#include <QComboBox>
#include <QProgressBar>
#include <QGroupBox>
#include <QTabWidget>
#include <QTreeWidget>
#include <QTableWidget>
#include <QSlider>
#include <QSpinBox>
#include <QSignalBlocker>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QSocketNotifier>
#include <QTimer>
#include <QByteArray>
#include <QMap>
#include <QSet>
#include <QDebug>
#include <cstdio>
#include <functional>
#include <unistd.h>

static QString s(const QJsonValue &v) { return v.isString() ? v.toString() : v.isDouble() ? QString::number(v.toInt()) : QString(); }
static QString clean(QString t) { if (t.size()>=2 && t.front()=='"' && t.back()=='"') t=t.mid(1,t.size()-2); return t.replace("\"\"", "\""); }
static QString mapped(const QString &t) {
 const QString x=t.toUpper();
 if (x=="PUSHBUTTON"||x=="DEFPUSHBUTTON"||x=="BUTTON") return "button";
 if (x=="AUTOCHECKBOX"||x=="CHECKBOX"||x=="3STATE"||x=="AUTO3STATE") return "checkbox";
 if (x=="RADIOBUTTON"||x=="AUTORADIOBUTTON") return "radio";
 if (x=="EDITTEXT"||x=="EDIT") return "edit";
 if (x=="LTEXT"||x=="RTEXT"||x=="CTEXT"||x=="STATIC"||x=="ICON") return "label";
 if (x=="LISTBOX") return "list";
 if (x=="COMBOBOX") return "combo";
 if (x=="GROUPBOX") return "group";
 if (x=="PROGRESSBAR"||x=="CONTROL_PROGRESS") return "progress";
 if (x=="TABCONTROL"||x=="SYSTABCONTROL32") return "tab";
 if (x=="TREEVIEW"||x=="SYSTREEVIEW32") return "tree";
 if (x=="LISTVIEW"||x=="SYSLISTVIEW32") return "table";
 if (x=="TRACKBAR"||x=="MSCTLS_TRACKBAR32") return "slider";
 if (x=="UPDOWN"||x=="MSCTLS_UPDOWN32") return "spin";
 if (x=="RICHEDIT"||x=="RICHEDIT20A"||x=="RICHEDIT20W") return "multiedit";
 return "unsupported";
}
static void writeJsonLine(const QJsonObject &v) {
 const QByteArray bytes=QJsonDocument(v).toJson(QJsonDocument::Compact)+"\n";
 fwrite(bytes.constData(),1,size_t(bytes.size()),stdout); fflush(stdout);
}
class ObservedDialog : public QDialog {
public:
 std::function<void()> closing;
protected:
 void closeEvent(QCloseEvent *e) override { if(closing) closing(); QDialog::closeEvent(e); }
};
class Bridge : public QObject {
public:
 ObservedDialog dlg;
 QMap<int,QWidget*> controls;
 int built=0, unsupported=0;
 bool quiet=false;
 QByteArray pending;
 Bridge() {
  dlg.setWindowTitle("ooDialog Qt6"); dlg.resize(600,380);
  dlg.closing=[this]{ event(0,"dialogClose"); };
 }
 void event(int id, QString type, QJsonValue value=QJsonValue()) {
  if (quiet) return;
  QJsonObject out{{"type","event"},{"id",id},{"event",type}};
  if (!value.isUndefined()) out.insert("value",value);
  writeJsonLine(out);
 }
 QWidget* createWidget(const QString &kind,int id,const QString &caption,int x,int y,int w,int h) {
  QWidget *c=nullptr;
  if (kind=="button") { auto *p=new QPushButton(caption,&dlg); connect(p,&QPushButton::clicked,this,[this,id]{event(id,"click");}); c=p; }
  else if (kind=="checkbox") { auto *p=new QCheckBox(caption,&dlg); connect(p,&QCheckBox::toggled,this,[this,id](bool v){event(id,"click",v);}); c=p; }
  else if (kind=="radio") { auto *p=new QRadioButton(caption,&dlg); connect(p,&QRadioButton::toggled,this,[this,id](bool v){event(id,"click",v);}); c=p; }
  else if (kind=="edit") { auto *p=new QLineEdit(&dlg); p->setText(caption); connect(p,&QLineEdit::textEdited,this,[this,id](const QString &v){event(id,"change",v);}); c=p; }
  else if (kind=="label") c=new QLabel(caption,&dlg);
  else if (kind=="multiedit") {auto *p=new QTextEdit(&dlg); connect(p,&QTextEdit::textChanged,this,[this,id,p]{event(id,"change",p->toPlainText());});c=p;}
  else if (kind=="list") {auto *p=new QListWidget(&dlg); connect(p,&QListWidget::currentRowChanged,this,[this,id](int row){event(id,"selection",row);}); c=p;}
  else if (kind=="combo") {auto *p=new QComboBox(&dlg); connect(p,QOverload<int>::of(&QComboBox::currentIndexChanged),this,[this,id](int n){event(id,"selection",n);}); c=p;}
  else if (kind=="group") c=new QGroupBox(caption,&dlg);
  else if (kind=="progress") c=new QProgressBar(&dlg);
  else if (kind=="tab") {auto *p=new QTabWidget(&dlg);connect(p,&QTabWidget::currentChanged,this,[this,id](int n){event(id,"selection",n);});c=p;}
  else if (kind=="tree") {auto *p=new QTreeWidget(&dlg);p->setHeaderHidden(true);connect(p,&QTreeWidget::currentItemChanged,this,[this,id](QTreeWidgetItem *cur,QTreeWidgetItem*){if(cur)event(id,"selection",cur->text(0));});c=p;}
  else if (kind=="table") {auto *p=new QTableWidget(&dlg);p->setColumnCount(1);p->setHorizontalHeaderLabels({"Item"});connect(p,&QTableWidget::currentCellChanged,this,[this,id](int row,int,int,int){event(id,"selection",row);});c=p;}
  else if (kind=="slider") {auto *p=new QSlider(Qt::Horizontal,&dlg);connect(p,&QSlider::valueChanged,this,[this,id](int n){event(id,"change",n);});c=p;}
  else if (kind=="spin") {auto *p=new QSpinBox(&dlg);connect(p,QOverload<int>::of(&QSpinBox::valueChanged),this,[this,id](int n){event(id,"change",n);});c=p;}
  if(c){c->setObjectName(QString::number(id));c->setGeometry(x,y,qMax(w,10),qMax(h,10));controls.insert(id,c);built++;}
  return c;
 }
 bool build(const QJsonObject &root,QString &error) {
  if (root.value("format").toString()!="windows-rc-json-v4") {error="expected windows-rc-json-v4";return false;}
  const auto resources=root.value("resources").toArray();
  QJsonObject dialog;
  for(const auto &v:resources){ const auto r=v.toObject(); if(r.value("type").toString().startsWith("DIALOG",Qt::CaseInsensitive)||r.value("resourceType").toString().startsWith("DIALOG",Qt::CaseInsensitive)){dialog=r;break;} }
  if(dialog.isEmpty()) {error="no DIALOG/DIALOGEX resource";return false;}
  struct Def { QString kind,caption; int id,x,y,w,h; };
  QList<Def> definitions; QSet<int> ids;
  const auto entries=dialog.value("entries").toArray();
  for(const auto &v:entries){const auto e=v.toObject();
   if(e.value("kind").toString()=="property" && e.value("name").toString().toUpper()=="CAPTION") dlg.setWindowTitle(clean(s(e.value("value"))));
   if(e.value("kind").toString()!="control") continue;
   const QString raw=e.value("controlType").toString(), kind=mapped(raw);
   if(kind=="unsupported"){unsupported++; continue;}
   const auto a=e.value("arguments").toArray();
   const bool withCaption=(kind=="button"||kind=="checkbox"||kind=="radio"||kind=="label"||kind=="group");
   const int off=withCaption?2:1;
   const auto idValue=e.value("resolvedControlId");
   const QString idText=!idValue.isUndefined()?s(idValue): (a.size()>withCaption?s(a.at(withCaption?1:0)):QString());
   bool ok=false; int id=idText.toInt(&ok);
   if(!ok){error="unresolved control ID: "+idText;return false;}
   if(ids.contains(id)){error="duplicate control ID: "+QString::number(id);return false;}
   ids.insert(id);
   if(a.size()<off+4){error="invalid geometry for "+QString::number(id);return false;}
   auto num=[&](int i)->int {return s(a.at(i)).toInt();};
   const QString cap=withCaption?clean(s(a.at(0))):QString();
   // RC uses dialog units. Initial display heuristic only; DLU exact conversion is pending.
   definitions.append({kind,cap,id,num(off)*2,num(off+1)*2,num(off+2)*2,num(off+3)*2});
  }
  for(const auto &d:definitions) if(d.kind=="group") createWidget(d.kind,d.id,d.caption,d.x,d.y,d.w,d.h);
  for(const auto &d:definitions) if(d.kind!="group") createWidget(d.kind,d.id,d.caption,d.x,d.y,d.w,d.h);
  int maxX=320,maxY=180;for(const auto &d:definitions){maxX=qMax(maxX,d.x+d.w+16);maxY=qMax(maxY,d.y+d.h+48);}dlg.resize(maxX,maxY);
  writeJsonLine({{"type","ready"},{"controls",built},{"unsupported",unsupported},{"dialog",s(dialog.value("id"))}});
  return true;
 }
 void command(const QJsonObject &j) {
  const QString action=j.value("action").toString(); const int id=j.value("id").toInt(-1); QWidget *w=controls.value(id,nullptr);
  if(action=="inspectDialog") {
   QWidget *focus=dlg.focusWidget();
   bool ok=false; int focusId=focus ? focus->objectName().toInt(&ok) : -1;
   writeJsonLine({{"type","dialogState"},{"visible",dlg.isVisible()},
                  {"modal",dlg.isModal()},{"result",dlg.result()},
                  {"focusId",ok?focusId:-1},{"width",dlg.width()},{"height",dlg.height()}});
   return;
  }
  if(action=="showDialog") {
   dlg.setModal(j.value("modal").toBool(false));dlg.show();
   writeJsonLine({{"type","ack"},{"action",action}});return;
  }
  if(action=="hideDialog") {
   dlg.hide();writeJsonLine({{"type","ack"},{"action",action}});return;
  }
  if(action=="endDialog") {
   const int result=j.value("result").toInt(0);
   dlg.done(result);
   writeJsonLine({{"type","dialogEnded"},{"result",result}});return;
  }
  if(action=="inspect") {QJsonObject out{{"type","state"},{"id",id}};if(!w){writeJsonLine({{"type","error"},{"reason","unknown control"},{"id",id}});return;}out.insert("enabled",w->isEnabled());out.insert("visible",w->isVisible());out.insert("class",w->metaObject()->className());if(auto p=qobject_cast<QLineEdit*>(w))out.insert("text",p->text());else if(auto p=qobject_cast<QTextEdit*>(w))out.insert("text",p->toPlainText());else if(auto p=qobject_cast<QAbstractButton*>(w)){out.insert("text",p->text());out.insert("checked",p->isChecked());}else if(auto p=qobject_cast<QLabel*>(w))out.insert("text",p->text());else if(auto p=qobject_cast<QProgressBar*>(w))out.insert("value",p->value());else if(auto p=qobject_cast<QSlider*>(w))out.insert("value",p->value());else if(auto p=qobject_cast<QSpinBox*>(w))out.insert("value",p->value());else if(auto p=qobject_cast<QComboBox*>(w))out.insert("selection",p->currentIndex());else if(auto p=qobject_cast<QListWidget*>(w))out.insert("selection",p->currentRow());else if(auto p=qobject_cast<QTabWidget*>(w))out.insert("selection",p->currentIndex());writeJsonLine(out);return;}
  if(action=="quit"){dlg.hide();QApplication::quit();return;}
  if(action=="ping"){writeJsonLine({{"type","pong"}});return;}
  if(!w){writeJsonLine({{"type","error"},{"reason","unknown control"},{"id",id}});return;}
  if(action=="setText") {if(auto p=qobject_cast<QLineEdit*>(w))p->setText(s(j.value("value"))); else if(auto p=qobject_cast<QTextEdit*>(w))p->setPlainText(s(j.value("value"))); else if(auto p=qobject_cast<QLabel*>(w))p->setText(s(j.value("value")));else if(auto p=qobject_cast<QAbstractButton*>(w))p->setText(s(j.value("value")));else if(auto p=qobject_cast<QGroupBox*>(w))p->setTitle(s(j.value("value")));else {writeJsonLine({{"type","error"},{"reason","setText unsupported"},{"id",id}});return;}}
  else if(action=="enable")w->setEnabled(j.value("value").toBool());
  else if(action=="show")w->setVisible(j.value("value").toBool());
  else if(action=="focus")w->setFocus();
  else if(action=="addItem") {if(auto p=qobject_cast<QListWidget*>(w))p->addItem(s(j.value("value")));else if(auto p=qobject_cast<QComboBox*>(w))p->addItem(s(j.value("value")));else if(auto p=qobject_cast<QTabWidget*>(w))p->addTab(new QWidget(p),s(j.value("value")));else if(auto p=qobject_cast<QTreeWidget*>(w))p->addTopLevelItem(new QTreeWidgetItem(QStringList{s(j.value("value"))}));else if(auto p=qobject_cast<QTableWidget*>(w)){int row=p->rowCount();p->insertRow(row);p->setItem(row,0,new QTableWidgetItem(s(j.value("value"))));}else {writeJsonLine({{"type","error"},{"reason","not a list/combo"},{"id",id}});return;}}
  else if(action=="setValue") {if(auto p=qobject_cast<QProgressBar*>(w))p->setValue(j.value("value").toInt());else if(auto p=qobject_cast<QSlider*>(w))p->setValue(j.value("value").toInt());else if(auto p=qobject_cast<QSpinBox*>(w))p->setValue(j.value("value").toInt());else if(auto p=qobject_cast<QAbstractButton*>(w);p&&p->isCheckable())p->setChecked(j.value("value").toBool());else {writeJsonLine({{"type","error"},{"reason","not progress/checkbox"},{"id",id}});return;}}
  else if(action=="key") {
   const QString key=j.value("value").toString().toUpper();
   const int code=key=="TAB"?Qt::Key_Tab:key=="BACKTAB"?Qt::Key_Backtab:key=="RETURN"?Qt::Key_Return:key=="ESCAPE"?Qt::Key_Escape:0;
   if(!code){writeJsonLine({{"type","error"},{"reason","unsupported key"}});return;}
   QKeyEvent press(QEvent::KeyPress,code,Qt::NoModifier);
   QApplication::sendEvent(w,&press);
  }
  else if(action=="activate") {if(auto p=qobject_cast<QPushButton*>(w))p->click();else {writeJsonLine({{"type","error"},{"reason","not button"},{"id",id}});return;}}
  else if(action=="inspectFocus") {
   writeJsonLine({{"type","focus"},{"id",id},{"focused",w->hasFocus()}});return;
  }
  else if(action=="select") {if(auto p=qobject_cast<QListWidget*>(w))p->setCurrentRow(j.value("value").toInt());else if(auto p=qobject_cast<QComboBox*>(w))p->setCurrentIndex(j.value("value").toInt());else if(auto p=qobject_cast<QTabWidget*>(w))p->setCurrentIndex(j.value("value").toInt());else if(auto p=qobject_cast<QTableWidget*>(w))p->setCurrentCell(j.value("value").toInt(),0);else if(auto p=qobject_cast<QTreeWidget*>(w))p->setCurrentItem(p->topLevelItem(j.value("value").toInt()));else {writeJsonLine({{"type","error"},{"reason","not list/combo"},{"id",id}});return;}}
  else {writeJsonLine({{"type","error"},{"reason","unknown action"},{"action",action}});return;}
  writeJsonLine({{"type","ack"},{"action",action},{"id",id}});
 }
 void consume() {
  char buf[4096]; const ssize_t n=::read(STDIN_FILENO,buf,sizeof(buf));
  if(n<=0){QApplication::quit();return;}
  pending.append(buf,int(n));
  while(true){int pos=pending.indexOf('\n');if(pos<0)break;const QByteArray line=pending.left(pos);pending.remove(0,pos+1);QJsonParseError pe;auto doc=QJsonDocument::fromJson(line,&pe);if(pe.error==QJsonParseError::NoError&&doc.isObject())command(doc.object());else writeJsonLine({{"type","error"},{"reason","bad command JSON"}});}
 }
};
int main(int argc,char **argv) {
 QApplication app(argc,argv);app.setQuitOnLastWindowClosed(false);QString file;bool selftest=false;
 for(int i=1;i<argc;i++){const QString a=QString::fromLocal8Bit(argv[i]);if(a=="--self-test")selftest=true;else file=a;}
 if(file.isEmpty()){fprintf(stderr,"usage: oodialog-qt6 [--self-test] resource-v4.json\n");return 2;}
 QFile f(file);if(!f.open(QIODevice::ReadOnly)){fprintf(stderr,"cannot open resource\n");return 2;}
 QJsonParseError err;auto doc=QJsonDocument::fromJson(f.readAll(),&err);if(err.error!=QJsonParseError::NoError||!doc.isObject()){fprintf(stderr,"invalid JSON\n");return 2;}
 Bridge bridge;QString why;if(!bridge.build(doc.object(),why)){fprintf(stderr,"resource rejected: %s\n",why.toUtf8().constData());return 3;}
 if(selftest){ if(bridge.built<1){fprintf(stderr,"no controls constructed\n");return 4;}for(auto w:bridge.controls)if(w->parentWidget()!=&bridge.dlg)return 5; writeJsonLine({{"type","selftest"},{"result","pass"},{"controls",bridge.built}});return 0;}
 bridge.dlg.show(); QSocketNotifier input(STDIN_FILENO,QSocketNotifier::Read,&bridge.dlg);
 QObject::connect(&input,&QSocketNotifier::activated,&bridge.dlg,[&](auto...){bridge.consume();});
 return app.exec();
}
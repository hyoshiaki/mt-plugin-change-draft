package MT::ChangeDraft::L10N::ja;

use strict;
use utf8;
use base 'MT::ChangeDraft::L10N::en_us';
use vars qw( %Lexicon );

%Lexicon = (

    'Enables draft for a published entry and page.' => '公開済みの記事やウェブページに対する下書き保存を可能にします。',

    'Change Draft Status' => '変更下書きステータス',

    'Change Draft' => '変更下書き',
    'Change Draft of "[_1]"' => '「[_1]」の変更下書き',
	'Changing Draft' => '変更下書き',
    'Changing Draft of "[_1]"' => '「[_1]」の変更下書き',
    'Changed Backup' => '変更済みバックアップ',
    'Changed Backup of "[_1]"' => '「[_1]」の変更済みバックアップ',
    'Others' => 'その他',
	'Successfully create Changing draft of [_1] object(s).' => '[_1]件の変更下書きを作成しました。',

    'This is changing draft of <a href="[_3]">[_1] (id:[_2])</a>([_5]). When this is published, <a href="[_4]">the original page</a> will be replaced.'
        => '<a href="[_3]">[_1] (id:[_2])</a> の変更下書きです([_5])。公開されると<a href="[_4]">元のページ</a>が差し替えられます。',
    'This is changed backup of <a href="[_3]">[_1] (id:[_2])</a>([_5]). When this is published, <a href="[_4]">the original page</a> will be reverted.'
        => '<a href="[_3]">[_1] (id:[_2])</a> の変更済みバックアップです([_5])。公開されると<a href="[_4]">元のページ</a>が元に戻ります。',
    'This has changing draft or changed backup. Your changes never update them.'
        => '変更下書きか、変更済みのバックアップが存在します。このページで変更を加えても、それらには反映されません。',

    'Create' => '作成',
    'New Change Draft' => '新しい変更下書き',
    'Edit Change Draft' => '変更下書きの編集',
    'Delete' => '削除',
    'Restore' => '復元',

    'Are you sure you delete change draft?' => '変更下書きを削除してもよろしいですか？',
    'Are you sure you publish change draft?' => '変更下書きを公開し、元のページと差し替えてもよろしいですか？',
    'Are you sure you restore backup before change?' => 'バックアップを復元し、元のページに差し替えてよろしいですか？',

    # config_template
    'You can change more settings in system plugin settings:'
        => 'システム全体のプラグイン設定で細かな設定が可能です:',
    'Open' => '開く',
    'Ask to system administrator.' => 'システム管理者に問い合わせください。',
    'Follows the system setting - [_1]' => 'システム全体の設定に従う([_1])',
    'Enables' => '有効にする',
    'Disables' => '無効にする',
    'Column in Listing' => '一覧の列表示',
    'Diplays Change Draft column in entries and pages listing as default?'
        => '記事とウェブページの一覧で変更下書きの列をデフォルトで表示しますか？',
    'Hide as default' => 'デフォルトで非表示',
    'Show as default' => 'デフォルトで表示',
    'Force to display' => '強制的に表示',
    'You can also set display option as ChangeDraftDisplayListColumn in mt-config.cgi. It takes optional, default or force.'
        => 'mt-config.cgi のChangeDraftDisplayListColumn環境変数としても設定できます。値にはoptional、default、forceのいずれかを指定ください。',
    'Widget in Editing' => '編集画面のウィジェット',
    'Displays Change Draft widget on sidebar in editing entry or page screen.'
        => '記事やウェブページの編集画面のサイドバーに編集用下書きのウィジェットを表示しますか？',
    'Displays' => '表示する',
    'Hides' => '表示しない',

    'Multiple Drafts' => '複数の下書き',
    'Allows multipe drafts for each entry or page?'
        => 'ひとつの記事またはウェブページに複数の変更要下書きを作成することを許可しますか？',
    'It is useful for two or more times future update.'
        => '複数回の時間指定更新を行うときに便利です。',
    'Multiple drafts for each' => '複数の下書きを許可',
    'Single draft for each' => '下書きはひとつまで',

    'This object is not copiable.' => 'このオブジェクトは編集下書きを作成できません。',
    'You can edit and save keeping published page.' => '公開されたページを保ったまま編集と保存ができます。',
    '<a href="http://www.ideamans.com/mt/changedraft/">About ChangeDraft</a>'
        => '<a href="http://www.ideamans.com/mt/changedraft/">ChangeDraftについて</a>',
);

1;


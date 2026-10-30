# PICOCRAFT

8×8マス、高さ8段（地面を除いて7段）の世界を歩き、12色のブロック（赤色のRubyを含む）を置いたり壊したりする一人称3Dサンドボックスです。地面は壊せず、地面の上に最大448個のブロックを配置できます。以前の高さ4段のセーブも読み込めます。

タイトル画面では上下で `NEW WORLD`（新しいワールド）または `CONTINUE`（保存したワールド）を選び、AまたはSTARTで決定します。セーブがない場合は `CONTINUE` を選べません。新しいワールドを始めても、セーブするまでは以前の保存データを上書きしません。

ゲーム中の操作：

- 十字キー上下左右：視線を動かす
- A / B：前進／後退
- L：照準の面にブロックを置く
- R：照準のブロックを壊す
- START：ジャンプ
- SELECT：メニューを開く

メニューでは十字キーで色、`SAVE`、`BACK`を選び、Aで決定します。色を選ぶとゲームに戻ります。`SAVE` はワールドを1枠に保存します。SELECTまたはBでもゲームに戻れます。保存するのはブロック配置で、再開時の位置や向きは初期状態です。ブラウザではそのブラウザの保存領域、実機ではSDカードに保存します。

ブラウザでは [PicoRubitto Studio](https://picorubitto.ngt-y.uk/) の Picocraft ボタンから開けます。キーボードは矢印、Z（A）、X（B）、Q/E（L/R）、O（SELECT）、P（START）です。

実機用ROMは[PicoRubitto](https://github.com/ngtyuk/picorubitto)の `ruby tools/build/workflow.rb game /path/to/picocraft` で生成します。効果音を作り直すときは `--prepare-assets` を追加します。対応するエンジンのUF2が別途必要です。

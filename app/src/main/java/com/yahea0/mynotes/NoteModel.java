package com.yahea0.mynotes;

public class NoteModel {
    public long id;
    public String title;
    public String content;
    public String category;
    public String date;

    public NoteModel(long id, String title, String content, String category, String date) {
        this.id = id;
        this.title = title;
        this.content = content;
        this.category = category;
        this.date = date;
    }
}

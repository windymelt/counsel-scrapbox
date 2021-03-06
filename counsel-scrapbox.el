;;; scrapbox.el --- scrapbox client
;;; Commentary:
;;; Code:

(require 'ivy)

(defgroup counsel-scrapbox nil
  "sbx with counsel interface"
  :prefix "counsel-scrapbox-"
  :group 'counsel)

(defcustom counsel-scrapbox-command-sbx
  "sbx"
  "*A sbx command"
  :type 'string
  :group 'counsel-scrapbox)

(defcustom counsel-scrapbox-command-sbx-arg-list
  '("page" "list" "" "--jq" "map(.title)[]" "-L" "999")
  "*Arguments for getting page list"
  :type '(repeat string)
  :group 'counsel-scrapbox)

(defcustom counsel-scrapbox-command-sbx-project
  ""
  "* Scrapbox roject"
  :type 'string
  :group 'counsel-scrapbox)

(ivy-set-actions 'counsel-scrapbox
                 '(("o" counsel-scrapbox--open-page "open file")
                   ("y" kill "copy")
                   ("r" counsel-scrapbox--kill-cache-and-reopen "Kill cache")))

(defmacro counsel-scrapbox--line-string ()
  `(buffer-substring-no-properties
    (line-beginning-position) (line-end-position)))

(defun counsel-scrapbox--list-candidates ()
  (if counsel-scrapbox--candidates-cache
      counsel-scrapbox--candidates-cache
    (setq counsel-scrapbox--candidates-cache
          (with-temp-buffer
            (unless (zerop (apply #'call-process
                                  counsel-scrapbox-command-sbx nil t nil
                                  counsel-scrapbox-command-sbx-arg-list))
              (error "Failed: Can't get sbx list candidates"))
            (let ((pages))
              (goto-char (point-min))
              (while (not (eobp))
                (push (counsel-scrapbox--line-string) pages)
                (forward-line 1))
              (reverse pages))))))

(defvar counsel-scrapbox--candidates-cache nil)
(defun counsel-scrapbox--kill-cache-and-reopen (_)
  (setq counsel-scrapbox--candidates-cache nil)
  (counsel-scrapbox))

(defun counsel-scrapbox--reveal-dquotes (s)
  ""
  (let* ((s1 (replace-regexp-in-string "\"\\(.*\\)\"" "\\1" s))
         (s2 (replace-regexp-in-string "/" "%2F" s1 t t)))
    s2))

(defun counsel-scrapbox--open-page (page)
  "Open PAGE."
  (interactive)
  (message "Opening page...")
  (let* ((page-no-dquotes (counsel-scrapbox--reveal-dquotes page))
         (buf (generate-new-buffer page-no-dquotes)))
    (switch-to-buffer buf)
    (apply #'call-process counsel-scrapbox-command-sbx nil t nil
           `("api" ,(concat "pages/" counsel-scrapbox-command-sbx-project "/" page-no-dquotes "/text")))
    (scrapbox-mode)
    (goto-char (point-min))
    (read-only-mode)
    (message "Opened page")))

;;;###autoload
(defun counsel-scrapbox ()
  "Ivy interface for scrapbox."
  (interactive)
  (message "Loading index...")
  (ivy-read (concat "scrapbox [M-o to menu]: ") (counsel-scrapbox--list-candidates)
            :keymap counsel-describe-map
            :preselect nil
            :history 'counsel-describe-symbol-history
            :require-match t
            :sort t
            :action #'counsel-scrapbox--open-page
            :caller 'counsel-scrapbox))

;;; Mode
(defvar scrapbox-mode-hook nil)
(defun kill-this-buffer ()
  (interactive)
  (kill-buffer (current-buffer)))

(defvar scrapbox-mode-map
  (let ((map (make-keymap)))
    (define-key map "\M-." 'scrapbox-mode-open-page-at-point)
    (define-key map "q" 'kill-this-buffer)
    (define-key map "/" 'counsel-scrapbox)
    map)
  "Keymap for Scrapbox major mode")

(defconst scrapbox-font-lock-keywords-1
  (list
   '("\\[\\[.+\\]\\]" . font-lock-keyword-face)
   '("\\[* .+\\]" . font-lock-keyword-face)
   '("\\[.+\\]" . font-lock-doc-face)
   '("`.+`" . font-lock-function-name-face)
   '("code:.+\n" . font-lock-function-name-face)
   '("#\\w+" . font-lock-function-name-face))
  "minimal highlighting expressions for Scrapbox mode")

(defvar scrapbox-mode-syntax-table
  (let ((st (make-syntax-table)))
    st))

(defun scrapbox-mode-open-page-at-point ()
  "Open the page at the point."
  (interactive)
  (let ((page (symbol-name (symbol-at-point))))
    (counsel-scrapbox--open-page page)))

(defun scrapbox-mode ()
  "Major mode for visiting Scrapbox"
  (interactive)
  (kill-all-local-variables)
  (set-syntax-table scrapbox-mode-syntax-table)
  (use-local-map scrapbox-mode-map)
  (set (make-local-variable 'font-lock-defaults) '(scrapbox-font-lock-keywords-1))
  (setq major-mode 'scrapbox-mode)
  (setq mode-name "Scrapbox"))

(provide 'counsel-scrapbox)
;;; scrapbox.el ends here

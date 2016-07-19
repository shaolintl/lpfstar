(*
 * Copyright (C) 2003-2004:
 *    Stefano Zacchiroli <zack@cs.unibo.it>
 *    for the HELM Team http://helm.cs.unibo.it/
 *
 *  This file is part of HELM, an Hypertextual, Electronic
 *  Library of Mathematics, developed at the Computer Science
 *  Department, University of Bologna, Italy.
 *
 *  HELM is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *
 *  HELM is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with HELM; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston,
 *  MA  02111-1307, USA.
 *
 *  For details, see the HELM World-Wide-Web page,
 *  http://helm.cs.unibo.it/
 *)

class threadSafe:
  object

      (** execute 'action' in mutual exclusion between all other threads *)
    method private doCritical: 'a. 'a lazy_t -> 'a

      (** execute 'action' acting as a 'reader' i.e.: multiple readers can act
      at the same time but no writer can act until no readers are acting *)
    method private doReader: 'a. 'a lazy_t -> 'a

      (** execute 'action' acting as a 'writer' i.e.: when a writer is acting,
      no readers or writer can act, beware that writers can starve *)
    method private doWriter: 'a. 'a lazy_t -> 'a

  end

